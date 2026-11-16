defmodule NewYou.Proof.P819 do
  @moduledoc false
  import ExUnit.Assertions
  import Phoenix.ConnTest
  alias NewYou.Proof.{DeliveryRecoveryScenarios, P805, P805PublicResponse}
  @endpoint NewYouWeb.Endpoint

  def comm_crash_after_admission,
    do: DeliveryRecoveryScenarios.process_death(:after_admission, :"transaction.after_commit")

  def comm_crash_before_invoke,
    do: DeliveryRecoveryScenarios.process_death(:before_invoke, :"provider.before_invoke")

  def comm_crash_after_invoke,
    do:
      DeliveryRecoveryScenarios.process_death(
        :after_invoke,
        :"provider.after_invoke_before_persist"
      )

  def comm_recheck_eligible, do: DeliveryRecoveryScenarios.pre_invocation_recheck(:eligible)

  def comm_recheck_content_ineligible,
    do: DeliveryRecoveryScenarios.pre_invocation_recheck(:content_ineligible)

  def comm_recheck_capability_unavailable,
    do: DeliveryRecoveryScenarios.pre_invocation_recheck(:capability_unavailable)

  def comm_recheck_provider_unavailable,
    do: DeliveryRecoveryScenarios.pre_invocation_recheck(:provider_unavailable)

  def registration_neutral do
    P805.with_fixture(fn ->
      request = P805.request()

      projections =
        for _ <- 1..2 do
          input = P805.request(%{email: request.email})

          response =
            post(build_conn(), "/register", %{
              "registration" => %{
                "first_name" => input.first_name,
                "surname" => input.surname,
                "email" => input.email,
                "password" => input.password,
                "preferred_language" => "en",
                "confirmed_age_18" => "true",
                "terms_accepted" => "true",
                "privacy_accepted" => "true",
                "operation_id" => input.operation_id
              }
            })

          assert response.status == 200

          assert {:ok, projection} =
                   P805PublicResponse.project(200, response.resp_body, input.email, "en")

          projection
        end

      assert [first, first] = projections
    end)
  end

  def browser_en, do: NewYou.Proof.P819Browser.run("en")
  def browser_af, do: NewYou.Proof.P819Browser.run("af")
end
