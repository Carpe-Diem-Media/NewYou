defmodule NewYou.Identity.IdentityGrantTest do
  use ExUnit.Case, async: false

  alias Ecto.Adapters.SQL.Sandbox
  alias NewYou.Identity.IdentityGrant
  alias NewYou.Proof.P813HoldFixture
  alias NewYou.Repo

  test "an active assignment cannot be duplicated by changing approval details" do
    P813HoldFixture.with_fixture(fn fixture ->
      attrs =
        grant_attrs(
          fixture.actor.id,
          fixture.target.id,
          fixture.reviewer.id,
          :release_security_hold
        )

      assert {:error, %Ash.Error.Invalid{}} =
               create_grant(%{attrs | reason_code: :recovery_assistance})
    end)
  end

  test "the same capability can be assigned in a different target scope" do
    P813HoldFixture.with_fixture(fn fixture ->
      other_target = P813HoldFixture.member()

      assert {:ok, %IdentityGrant{}} =
               create_grant(
                 grant_attrs(
                   fixture.actor.id,
                   other_target.id,
                   fixture.approver.id,
                   :release_security_hold
                 )
               )
    end)
  end

  test "a revoked assignment can be replaced" do
    P813HoldFixture.with_fixture(fn fixture ->
      grant = fixture.grants.release
      assert {:ok, _} = Ash.update(grant, %{}, action: :revoke, authorize?: false)

      assert {:ok, %IdentityGrant{}} =
               create_grant(
                 grant_attrs(
                   fixture.actor.id,
                   fixture.target.id,
                   fixture.approver.id,
                   :release_security_hold
                 )
               )
    end)
  end

  test "concurrent writes for one active assignment have one winner" do
    P813HoldFixture.with_fixture(fn fixture ->
      target = P813HoldFixture.member()

      attrs =
        grant_attrs(fixture.actor.id, target.id, fixture.approver.id, :release_security_hold)

      parent = self()

      tasks =
        for _ <- 1..2 do
          Task.async(fn ->
            :ok = Sandbox.checkout(Repo, sandbox: false)

            try do
              ref = make_ref()
              send(parent, {:ready, self(), ref})

              receive do
                {:start, ^ref} ->
                  Repo.transaction(fn ->
                    %{rows: [[backend_pid, transaction_id]]} =
                      Repo.query!("SELECT pg_backend_pid(), txid_current()")

                    send(parent, {:grant_transaction, self(), backend_pid, transaction_id})
                    create_grant(attrs)
                  end)
              after
                10_000 -> raise "concurrent grant start deadline"
              end
            after
              :ok = Sandbox.checkin(Repo)
            end
          end)
        end

      workers =
        for _ <- 1..2 do
          receive do
            {:ready, pid, ref} -> {pid, ref}
          after
            5_000 -> flunk("concurrent grant worker did not become ready")
          end
        end

      Enum.each(workers, fn {pid, ref} -> send(pid, {:start, ref}) end)
      results = Enum.map(tasks, &Task.await(&1, 30_000))

      assert Enum.count(results, &match?({:ok, {:ok, %IdentityGrant{}}}, &1)) == 1,
             inspect(results)

      assert Enum.count(results, &active_assignment_conflict?/1) == 1,
             inspect(results)

      transactions =
        for _ <- 1..2 do
          receive do
            {:grant_transaction, pid, backend, transaction} -> {pid, backend, transaction}
          after
            5_000 -> flunk("concurrent grant transaction was not observed")
          end
        end

      assert length(Enum.uniq_by(transactions, &elem(&1, 1))) == 2
      assert length(Enum.uniq_by(transactions, &elem(&1, 2))) == 2
    end)
  end

  defp create_grant(attrs) do
    Ash.create(IdentityGrant, attrs, action: :provision, authorize?: false)
  end

  defp grant_attrs(subject_id, target_id, approver_id, capability) do
    %{
      subject_account_id: subject_id,
      target_account_id: target_id,
      approver_account_id: approver_id,
      role: :support,
      capability: capability,
      reason_code: :security_review,
      starts_at: DateTime.add(DateTime.utc_now(), -60),
      expires_at: DateTime.add(DateTime.utc_now(), 3600)
    }
  end

  defp active_assignment_conflict?({:error, %Ash.Changeset{errors: errors}}) do
    Enum.any?(errors, fn
      %Ash.Error.Changes.InvalidAttribute{private_vars: vars} ->
        Keyword.get(vars, :constraint) == "identity_grants_one_active_assignment_index" and
          Keyword.get(vars, :constraint_type) == :unique

      _error ->
        false
    end)
  end

  defp active_assignment_conflict?(_result), do: false
end
