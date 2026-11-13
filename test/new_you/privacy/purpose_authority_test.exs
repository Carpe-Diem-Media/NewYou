defmodule NewYou.Privacy.PurposeAuthorityTest do
  use ExUnit.Case, async: false

  require Ash.Query

  alias NewYou.{Identity, Privacy, Repo}
  alias NewYou.Privacy.{PurposeAuthority, PurposeEvent}
  alias NewYou.Proof.P805

  test "proof-only purpose records positive authority, terminal withdrawal and immutable history" do
    P805.with_fixture(fn ->
      request = P805.request()
      operation_id = Ecto.UUID.generate()
      P805.track_operation(operation_id)
      {:ok, registration} = Identity.register(request)

      assert {:ok, :missing} =
               Privacy.current_p817_proof_purpose(registration.account_id, operation_id)

      assert {:ok, :allowed} =
               Privacy.grant_p817_proof_purpose(registration.account_id, operation_id)

      assert {:ok, :already_allowed} =
               Privacy.grant_p817_proof_purpose(registration.account_id, operation_id)

      assert {:ok, :allowed} =
               Privacy.current_p817_proof_purpose(registration.account_id, operation_id)

      assert {:ok, :withdrawn} =
               Privacy.withdraw_p817_proof_purpose(registration.account_id, operation_id)

      assert {:ok, :already_withdrawn} =
               Privacy.withdraw_p817_proof_purpose(registration.account_id, operation_id)

      assert {:error, :withdrawn} =
               Privacy.grant_p817_proof_purpose(registration.account_id, operation_id)

      assert {:ok, :withdrawn} =
               Privacy.current_p817_proof_purpose(registration.account_id, operation_id)

      authority =
        PurposeAuthority
        |> Ash.Query.filter(
          subject_id == ^registration.account_id and source_operation_id == ^operation_id
        )
        |> Ash.read_one!(authorize?: false)

      events =
        PurposeEvent
        |> Ash.Query.filter(authority_id == ^authority.id)
        |> Ash.Query.sort(version: :asc)
        |> Ash.read!(authorize?: false)

      assert Enum.map(events, &{&1.transition, &1.version, &1.origin}) == [
               {:granted, 1, :p8_17_test_fixture},
               {:withdrawn, 2, :p8_17_test_fixture}
             ]

      assert {:error, _} =
               Ash.transact([PurposeAuthority], fn ->
                 Privacy.require_current_p817_proof_purpose_locked(
                   registration.account_id,
                   operation_id
                 )
               end)

      assert_raise Postgrex.Error, fn ->
        Repo.query!("UPDATE privacy_purpose_events SET version = 3 WHERE id = $1", [
          events |> hd() |> Map.fetch!(:id) |> Ecto.UUID.dump!()
        ])
      end

      assert_raise Postgrex.Error, fn ->
        Repo.query!("DELETE FROM privacy_purpose_events WHERE id = $1", [
          events |> hd() |> Map.fetch!(:id) |> Ecto.UUID.dump!()
        ])
      end

      assert_raise Postgrex.Error, fn ->
        Repo.query!(
          "UPDATE privacy_purpose_authorities SET state = 'allowed', version = 3 WHERE id = $1",
          [Ecto.UUID.dump!(authority.id)]
        )
      end

      assert_raise Postgrex.Error, fn ->
        Repo.query!("DELETE FROM privacy_purpose_authorities WHERE id = $1", [
          Ecto.UUID.dump!(authority.id)
        ])
      end

      fresh_process_result =
        Task.async(fn ->
          :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo, sandbox: false)

          try do
            Privacy.current_p817_proof_purpose(registration.account_id, operation_id)
          after
            Ecto.Adapters.SQL.Sandbox.checkin(Repo)
          end
        end)
        |> Task.await(10_000)

      assert fresh_process_result == {:ok, :withdrawn}
    end)
  end
end
