defmodule NewYou.Communications do
  @moduledoc """
  Communications owns the durable message obligation, attempt admissions and
  delivery evidence. Identity establishes the intent inside its source transaction.
  Verification uses its authorized encrypted capability. Magic login obtains a
  transient serialization of the same current proof from Identity. The id-only executor rechecks current owners,
  commits admission, then invokes its provider outside authoritative transactions.
  Provider evidence never changes Identity truth. Production egress is disabled.
  """
  @doc "Confirm the fixed policy for implemented verification and magic-login records. Preserve original source associations; execution rechecks Identity eligibility. This does not inspect individual records."
  @spec review_identity_reconciliation(String.t(), String.t()) :: {:ok, map()}
  def review_identity_reconciliation(candidate_id, canonical_id) do
    {:ok,
     %{
       "policy" => "preserve_original_account_association",
       "candidate_id" => candidate_id,
       "canonical_id" => canonical_id,
       "commands" => []
     }}
  end

  use Ash.Domain, otp_app: :new_you

  alias NewYou.Communications.{EnvelopeNonce, MessageIntent, ProtectedEnvelope}

  resources do
    resource MessageIntent
    resource ProtectedEnvelope
    resource EnvelopeNonce
    resource NewYou.Communications.DeliveryAttempt
  end

  @doc "Execute a trusted id-only delivery job. Public HTTP callers must not expose this internal boundary."
  @spec execute(String.t()) :: {:ok, atom()} | {:error, atom()}
  def execute(id), do: NewYou.Communications.Executor.execute(id)

  @doc "Accept only authenticated bounded provider evidence for an existing attempt. No operator bypass is provided."
  @spec reconcile(String.t(), atom(), String.t(), binary()) :: {:ok, :recorded} | {:error, atom()}
  def reconcile(id, outcome, reference, signature),
    do: NewYou.Communications.Executor.reconcile(id, outcome, reference, signature)

  @magic_login_fields [
    :source_operation_id,
    :source_reference,
    :destination,
    :destination_provenance,
    :destination_authorized_at,
    :locale,
    :role,
    :source_purpose,
    :render_schema,
    :content_item_id,
    :content_version_id,
    :translation_version_id,
    :content_sha256,
    :platform_name,
    :render_digest
  ]

  @doc "Establish a magic-login delivery obligation without retaining its bearer."
  @spec establish_magic_login(map()) ::
          {:ok, MessageIntent.t()} | {:error, :magic_login_unavailable}
  def establish_magic_login(attrs) when is_map(attrs) do
    with true <- valid_magic_login_attrs?(attrs),
         {:ok, content_binding} <- NewYou.Content.MagicLoginMessage.binding(attrs.locale) do
      platform_name = NewYou.platform_name()
      render_schema = "magic-login-v1"

      render_digest =
        :crypto.hash(
          :sha256,
          :erlang.term_to_binary({render_schema, platform_name}, [:deterministic])
        )
        |> Base.encode16(case: :lower)

      params =
        attrs
        |> Map.take([
          :source_operation_id,
          :source_reference,
          :destination,
          :destination_provenance,
          :destination_authorized_at,
          :locale,
          :role,
          :source_purpose,
          :render_schema
        ])
        |> Map.merge(content_binding)
        |> Map.merge(%{platform_name: platform_name, render_digest: render_digest})

      transact_magic_login(params)
    else
      _ -> {:error, :magic_login_unavailable}
    end
  rescue
    _ -> {:error, :magic_login_unavailable}
  end

  def establish_magic_login(_), do: {:error, :magic_login_unavailable}

  defp transact_magic_login(params) do
    case Ash.transact([MessageIntent], fn -> establish_magic_login_intent(params) end) do
      {:ok, {:ok, %MessageIntent{} = intent}} -> {:ok, intent}
      _ -> {:error, :magic_login_unavailable}
    end
  end

  defp valid_magic_login_attrs?(attrs) do
    attrs[:role] == :magic_login and attrs[:source_purpose] == "magic_login" and
      attrs[:render_schema] == "magic-login-v1" and
      attrs[:destination_provenance] == "identity_magic_login_issuance" and
      attrs[:locale] in ["en", "af"]
  end

  defp establish_magic_login_intent(params) do
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
         true <- Enum.all?(@magic_login_fields, &(Map.get(intent, &1) == Map.get(params, &1))) do
      {:ok, intent}
    else
      _ -> {:error, :magic_login_unavailable}
    end
  end

  @password_reset_fields [
    :source_operation_id,
    :source_reference,
    :destination,
    :destination_provenance,
    :destination_authorized_at,
    :locale,
    :role,
    :source_purpose,
    :render_schema,
    :content_item_id,
    :content_version_id,
    :translation_version_id,
    :content_sha256,
    :platform_name,
    :render_digest
  ]

  @doc "Establish a password-reset delivery obligation without retaining its bearer."
  @spec establish_password_reset(map()) ::
          {:ok, MessageIntent.t()} | {:error, :password_reset_unavailable}
  def establish_password_reset(attrs) when is_map(attrs) do
    with true <- valid_password_reset_attrs?(attrs),
         {:ok, content_binding} <- NewYou.Content.PasswordResetMessage.binding(attrs.locale) do
      platform_name = NewYou.platform_name()
      render_schema = "password-reset-v1"

      render_digest =
        :crypto.hash(
          :sha256,
          :erlang.term_to_binary({render_schema, platform_name}, [:deterministic])
        )
        |> Base.encode16(case: :lower)

      params =
        attrs
        |> Map.take([
          :source_operation_id,
          :source_reference,
          :destination,
          :destination_provenance,
          :destination_authorized_at,
          :locale,
          :role,
          :source_purpose,
          :render_schema
        ])
        |> Map.merge(content_binding)
        |> Map.merge(%{platform_name: platform_name, render_digest: render_digest})

      transact_password_reset(params)
    else
      _ -> {:error, :password_reset_unavailable}
    end
  rescue
    _ -> {:error, :password_reset_unavailable}
  end

  def establish_password_reset(_), do: {:error, :password_reset_unavailable}

  @recovery_fields [
    :source_operation_id,
    :source_reference,
    :destination,
    :destination_provenance,
    :destination_authorized_at,
    :locale,
    :role,
    :source_purpose,
    :render_schema,
    :content_item_id,
    :content_version_id,
    :translation_version_id,
    :content_sha256,
    :platform_name,
    :support_contact,
    :render_digest
  ]

  @doc "Establish a durable recovery obligation, binding exact development content when eligible."
  @spec establish_recovery(map()) ::
          {:ok, MessageIntent.t()} | {:error, :recovery_obligation_unavailable}
  def establish_recovery(attrs), do: establish_recovery_intent(attrs, :establish_recovery)

  @doc "Establish the distinct durable notice after recovery; missing content preserves a held obligation."
  @spec establish_recovery_notice(map()) ::
          {:ok, MessageIntent.t()} | {:error, :recovery_obligation_unavailable}
  def establish_recovery_notice(attrs),
    do: establish_recovery_intent(attrs, :establish_recovery_notice)

  defp establish_recovery_intent(attrs, action) when is_map(attrs) do
    role_binding =
      case action do
        :establish_recovery ->
          %{role: :account_recovery, source_purpose: "recovery", render_schema: "recovery-v1"}

        :establish_recovery_notice ->
          %{
            role: :recovery_security_notice,
            source_purpose: "recovery_completed",
            render_schema: "recovery-notice-v1"
          }
      end

    source_params =
      attrs
      |> Map.take([
        :source_operation_id,
        :source_reference,
        :destination,
        :destination_provenance,
        :destination_authorized_at,
        :locale
      ])

    case Ash.transact([MessageIntent], fn ->
           create_recovery_intent(source_params, role_binding, action)
         end) do
      {:ok, {:ok, %MessageIntent{} = intent}} -> {:ok, intent}
      _ -> {:error, :recovery_obligation_unavailable}
    end
  rescue
    _ -> {:error, :recovery_obligation_unavailable}
  end

  defp establish_recovery_intent(_, _), do: {:error, :recovery_obligation_unavailable}

  defp create_recovery_intent(source_params, role_binding, action) do
    expected =
      Map.merge(source_params, role_binding)
      |> Map.merge(recovery_content(role_binding, source_params.locale))

    with {:ok, intent} <-
           Ash.create(MessageIntent, Map.drop(expected, [:role, :source_purpose, :render_schema]),
             action: action,
             domain: __MODULE__,
             authorize?: false,
             upsert?: true,
             upsert_identity: :causal_obligation,
             upsert_fields: [],
             touch_update_defaults?: false
           ),
         true <- Enum.all?(@recovery_fields, &(Map.get(intent, &1) == Map.get(expected, &1))) do
      {:ok, intent}
    else
      _ -> {:error, :recovery_obligation_unavailable}
    end
  end

  defp recovery_content(role_binding, locale) do
    with {:ok, content} <- NewYou.Content.RecoveryMessage.binding(role_binding.role, locale),
         {:ok, support} <- recovery_support_contact(role_binding.role) do
      platform = NewYou.platform_name()

      Map.merge(content, %{
        platform_name: platform,
        support_contact: support,
        render_digest: recovery_render_digest(role_binding.render_schema, platform, support),
        terminal_reason: nil
      })
    else
      _ ->
        %{
          content_item_id: nil,
          content_version_id: nil,
          translation_version_id: nil,
          content_sha256: nil,
          platform_name: nil,
          support_contact: nil,
          render_digest: nil,
          terminal_reason: "content_ineligible"
        }
    end
  end

  defp recovery_support_contact(:recovery_security_notice),
    do: NewYou.Content.RecoveryMessage.support_contact()

  defp recovery_support_contact(:account_recovery), do: {:ok, nil}

  @doc false
  @spec recovery_render_digest(String.t(), String.t(), String.t() | nil) :: String.t()
  def recovery_render_digest(schema, platform, support) do
    :crypto.hash(:sha256, :erlang.term_to_binary({schema, platform, support}, [:deterministic]))
    |> Base.encode16(case: :lower)
  end

  defp transact_password_reset(params) do
    case Ash.transact([MessageIntent], fn -> establish_password_reset_intent(params) end) do
      {:ok, {:ok, %MessageIntent{} = intent}} -> {:ok, intent}
      _ -> {:error, :password_reset_unavailable}
    end
  end

  defp valid_password_reset_attrs?(attrs) do
    attrs[:role] == :password_reset and attrs[:source_purpose] == "password_reset" and
      attrs[:render_schema] == "password-reset-v1" and
      attrs[:destination_provenance] == "identity_password_reset_issuance" and
      attrs[:locale] in ["en", "af"]
  end

  defp establish_password_reset_intent(params) do
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
         true <- Enum.all?(@password_reset_fields, &(Map.get(intent, &1) == Map.get(params, &1))) do
      {:ok, intent}
    else
      _ -> {:error, :password_reset_unavailable}
    end
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
  send authority. The executor establishes that separately before admission.
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
