defmodule NewYou.Identity.IdentityGrantTest do
  use ExUnit.Case, async: false

  alias Ecto.Adapters.SQL.Sandbox
  alias NewYou.Identity.IdentityGrant
  alias NewYou.Proof.P813HoldFixture
  alias NewYou.Repo

  test "synthetic grant provisioning is absent from the production-compiled Resource" do
    P813HoldFixture.with_fixture(fn _fixture ->
      assert NewYou.Proof.P813.provisioning_after_production_compile() == :unavailable
    end)
  end

  test "provision accepts role and scope assignment, not a subject-selected capability" do
    P813HoldFixture.with_fixture(fn fixture ->
      target = P813HoldFixture.member()

      scoped =
        grant_attrs(fixture.actor.id, target.id, fixture.approver.id, :security_hold_release)

      attrs = scoped |> Map.delete(:scope) |> Map.put(:capability, :release_security_hold)

      assert {:error, _} = create_grant(attrs)

      assert {:ok, grant} = create_grant(scoped)
      assert IdentityGrant.permits?(grant, :release_security_hold)
      refute IdentityGrant.permits?(grant, :review_security_hold)

      assert {:error, _} = create_grant(%{scoped | role: :platform_administrator})
      assert {:error, _} = create_grant(%{scoped | scope: :unclassified})
    end)
  end

  test "capabilities derive only from the bounded Support role and scope catalogue" do
    for {scope, capability} <- [
          security_hold_restriction: :place_security_hold,
          security_hold_review: :review_security_hold,
          security_hold_release: :release_security_hold
        ] do
      assert IdentityGrant.permits?(%{role: :support, scope: scope}, capability)

      refute IdentityGrant.permits?(%{role: :platform_administrator, scope: scope}, capability)
    end

    refute IdentityGrant.permits?(
             %{role: :support, scope: :unclassified, capability: :release_security_hold},
             :release_security_hold
           )
  end

  test "an active assignment cannot be duplicated by changing approval details" do
    P813HoldFixture.with_fixture(fn fixture ->
      attrs =
        grant_attrs(
          fixture.actor.id,
          fixture.target.id,
          fixture.reviewer.id,
          :security_hold_release
        )

      assert {:error, %Ash.Error.Invalid{}} =
               create_grant(%{attrs | reason_code: :recovery_assistance})
    end)
  end

  test "the same role and scope can be assigned for a different target" do
    P813HoldFixture.with_fixture(fn fixture ->
      other_target = P813HoldFixture.member()

      assert {:ok, %IdentityGrant{}} =
               create_grant(
                 grant_attrs(
                   fixture.actor.id,
                   other_target.id,
                   fixture.approver.id,
                   :security_hold_release
                 )
               )
    end)
  end

  test "a revoked assignment can be replaced" do
    P813HoldFixture.with_fixture(fn fixture ->
      grant = fixture.grants.release

      assert {:ok, _} =
               Ash.update(grant, %{actor_id: fixture.approver.id, reason_code: :security_review},
                 action: :revoke,
                 authorize?: false
               )

      assert {:ok, %IdentityGrant{}} =
               create_grant(
                 grant_attrs(
                   fixture.actor.id,
                   fixture.target.id,
                   fixture.approver.id,
                   :security_hold_release
                 )
               )
    end)
  end

  test "concurrent writes for one active assignment have one winner" do
    P813HoldFixture.with_fixture(fn fixture ->
      target = P813HoldFixture.member()

      attrs =
        grant_attrs(fixture.actor.id, target.id, fixture.approver.id, :security_hold_release)

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

  defp grant_attrs(subject_id, target_id, approver_id, scope) do
    %{
      subject_account_id: subject_id,
      target_account_id: target_id,
      approver_account_id: approver_id,
      role: :support,
      scope: scope,
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
