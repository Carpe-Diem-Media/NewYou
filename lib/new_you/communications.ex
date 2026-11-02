defmodule NewYou.Communications do
  @moduledoc """
  Communications-owned creation of verification obligations.

  Identity must call this interface inside its source acceptance transaction. It does
  not authenticate the challenge, admit a delivery, or invoke a provider. The
  development content bindings are disabled in production builds.
  """
  use Ash.Domain, otp_app: :new_you

  alias NewYou.Communications.{EnvelopeNonce, MessageIntent, ProtectedEnvelope}

  resources do
    resource MessageIntent
    resource ProtectedEnvelope
    resource EnvelopeNonce
  end

  @development_fixtures Application.compile_env(
                          :new_you,
                          :verification_development_fixtures,
                          false
                        )

  @doc """
  Establishes an open intent and its encrypted capability in one transaction.

  The caller supplies the Identity-authorised source operation, the current
  Identity Token JTI, destination and provenance, authorisation time and locale.
  With development fixtures enabled, Communications resolves the exact pinned
  content binding for that locale. Identical causal replays return the existing
  intent; conflicting source data fails closed. A missing key or failed envelope
  write rolls back the new intent. The bearer is never returned or stored in the intent.

  This is an owner seam for a trusted source operation, not evidence of current
  send authority. The future executor must establish that separately.
  """
  @spec establish_verification(map(), binary()) :: {:ok, MessageIntent.t()} | {:error, atom()}
  if @development_fixtures do
    alias NewYou.Communications.EnvelopeCrypto

    @item "NEWYOU-CONTENTITEM-VERIFICATION-MESSAGE-EMAIL-ADDRESS"
    @version "NEWYOU-CONTENTVERSION-VERIFICATION-MESSAGE-EMAIL-ADDRESS-V1"
    @bindings %{
      "en" =>
        {"NEWYOU-CONTENTTRANSLATIONVERSION-VERIFICATION-MESSAGE-EMAIL-ADDRESS-EN-V1",
         "a8ceecc466497bd3d79ae9255a7f004b18461a2d6a1791028a68bcb1efd2a072"},
      "af" =>
        {"NEWYOU-CONTENTTRANSLATIONVERSION-VERIFICATION-MESSAGE-EMAIL-ADDRESS-AF-V1",
         "c3212222fdcd878af6bdc2b17895d4d6cab44e162814e2a8deee10b7fd916494"}
    }
    @source_fields [
      :source_operation_id,
      :source_reference,
      :destination,
      :destination_provenance,
      :destination_authorized_at,
      :locale,
      :content_item_id,
      :content_version_id,
      :translation_version_id,
      :content_sha256
    ]

    def establish_verification(attrs, bearer)
        when is_map(attrs) and is_binary(bearer) and byte_size(bearer) > 0 do
      case add_pinned_content_binding(attrs) do
        {:ok, attrs} ->
          if eligible?(attrs) do
            transact_verification(attrs, bearer)
          else
            {:error, :ineligible_content}
          end

        {:error, _} ->
          {:error, :ineligible_content}
      end
    rescue
      _ -> {:error, :verification_obligation_unavailable}
    end

    def establish_verification(_, _), do: {:error, :verification_obligation_unavailable}

    defp transact_verification(attrs, bearer) do
      id = Ash.UUID.generate()
      platform_name = NewYou.platform_name()

      digest =
        :crypto.hash(
          :sha256,
          :erlang.term_to_binary({"verification-v1", platform_name}, [:deterministic])
        )
        |> Base.encode16(case: :lower)

      params =
        attrs
        |> Map.take(@source_fields)
        |> Map.merge(%{id: id, platform_name: platform_name, render_digest: digest})

      case Ash.transact([MessageIntent, ProtectedEnvelope, EnvelopeNonce], fn ->
             establish(params, bearer, id)
           end) do
        {:ok, {:ok, intent}} -> {:ok, intent}
        {:ok, %MessageIntent{} = intent} -> {:ok, intent}
        _ -> {:error, :verification_obligation_unavailable}
      end
    end

    defp establish(params, bearer, id) do
      with {:ok, intent} <-
             Ash.create(MessageIntent, params,
               action: :establish,
               domain: __MODULE__,
               authorize?: false,
               upsert?: true,
               upsert_identity: :causal_obligation,
               upsert_fields: [],
               touch_update_defaults?: false
             ),
           true <- Enum.all?(@source_fields, &(Map.get(intent, &1) == Map.get(params, &1))) do
        finish_establish(intent, bearer, id)
      else
        _ -> {:error, :verification_obligation_unavailable}
      end
    end

    defp finish_establish(%{id: id} = intent, bearer, id) do
      nonce = :crypto.strong_rand_bytes(12)

      with {:ok, version, key} <- active_key(),
           {:ok, _} <-
             Ash.create(EnvelopeNonce, %{nonce: nonce},
               action: :reserve,
               domain: __MODULE__,
               authorize?: false
             ),
           {:ok, encrypted} <-
             EnvelopeCrypto.encrypt(
               key,
               {id, intent.source_reference, intent.source_purpose},
               bearer,
               nonce
             ),
           {:ok, _} <- store_envelope(intent, encrypted, version) do
        {:ok, intent}
      end
    end

    defp finish_establish(intent, _bearer, _id), do: {:ok, intent}

    defp store_envelope(intent, encrypted, version) do
      attrs =
        Map.merge(encrypted, %{
          message_intent_id: intent.id,
          source_reference: intent.source_reference,
          purpose: intent.source_purpose,
          key_version: version
        })

      Ash.create(ProtectedEnvelope, attrs, action: :store, domain: __MODULE__, authorize?: false)
    end

    defp active_key do
      case Application.get_env(:new_you, :communications_keyring) do
        %{active: version, keys: keys} when is_binary(version) and is_map(keys) ->
          case Map.get(keys, version) do
            key when is_binary(key) and byte_size(key) == 32 -> {:ok, version, key}
            _ -> {:error, :key_unavailable}
          end

        _ ->
          {:error, :key_unavailable}
      end
    end

    defp eligible?(attrs) do
      attrs[:destination_provenance] == "identity_challenge_issuance" and
        attrs[:content_item_id] == @item and attrs[:content_version_id] == @version and
        Map.get(@bindings, attrs[:locale]) ==
          {attrs[:translation_version_id], attrs[:content_sha256]}
    end

    defp add_pinned_content_binding(attrs) do
      content_fields = [
        :content_item_id,
        :content_version_id,
        :translation_version_id,
        :content_sha256
      ]

      if Enum.any?(content_fields, &Map.has_key?(attrs, &1)) do
        {:ok, attrs}
      else
        case Map.get(@bindings, attrs[:locale]) do
          {translation_version_id, content_sha256} ->
            {:ok,
             Map.merge(attrs, %{
               content_item_id: @item,
               content_version_id: @version,
               translation_version_id: translation_version_id,
               content_sha256: content_sha256
             })}

          _ ->
            {:error, :ineligible_content}
        end
      end
    end
  else
    def establish_verification(_, _), do: {:error, :ineligible_content}
  end
end
