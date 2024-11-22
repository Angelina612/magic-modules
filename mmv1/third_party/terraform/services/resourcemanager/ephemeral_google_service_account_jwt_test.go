package resourcemanager_test

import (
	"testing"

	"github.com/hashicorp/terraform-plugin-testing/helper/resource"
	"github.com/hashicorp/terraform-provider-google/google/acctest"
	"github.com/hashicorp/terraform-provider-google/google/envvar"
)

func TestAccEphemeralServiceAccountJwt_basic(t *testing.T) {
	t.Parallel()

	serviceAccount := envvar.GetTestServiceAccountFromEnv(t)
	targetServiceAccountEmail := acctest.BootstrapServiceAccount(t, "jwt-basic", serviceAccount)

	context := map[string]interface{}{
		"ephemeral_resource_name": "jwt",
		"ephemeral_reference":     "ephemeral.google_service_account_jwt.jwt",
		"target_service_account":  targetServiceAccountEmail,
		"sub":                     targetServiceAccountEmail,
	}

	resource.Test(t, resource.TestCase{
		PreCheck:                 func() { acctest.AccTestPreCheck(t) },
		ProtoV5ProviderFactories: acctest.ProtoV5ProviderFactories(t),
		ProtoV6ProviderFactories: acctest.ProtoV6ProviderFactories(t),
		Steps: []resource.TestStep{
			{
				Config: testAccEphemeralServiceAccountJwt_basic(context),
				Check: resource.ComposeTestCheckFunc(
					// Assert exact values
					resource.TestCheckResourceAttr(acctest.EchoResourceName, "data.target_service_account", context["target_service_account"].(string)),
					// Assert set
					resource.TestCheckResourceAttrSet(acctest.EchoResourceName, "data.jwt"),
					// Assert unset
					resource.TestCheckNoResourceAttr(acctest.EchoResourceName, "data.expires_in"),
				),
			},
		},
	})
}

func TestAccEphemeralServiceAccountJwt_withDelegates(t *testing.T) {
	t.Parallel()

	initialServiceAccount := envvar.GetTestServiceAccountFromEnv(t)
	delegateServiceAccountEmailOne := acctest.BootstrapServiceAccount(t, "jwt-delegate1", initialServiceAccount)          // SA_2
	delegateServiceAccountEmailTwo := acctest.BootstrapServiceAccount(t, "jwt-delegate2", delegateServiceAccountEmailOne) // SA_3
	targetServiceAccountEmail := acctest.BootstrapServiceAccount(t, "jwt-target", delegateServiceAccountEmailTwo)         // SA_4

	context := map[string]interface{}{
		"ephemeral_resource_name": "jwt",
		"ephemeral_reference":     "ephemeral.google_service_account_jwt.jwt",
		"target_service_account":  targetServiceAccountEmail,
		"delegate_1":              delegateServiceAccountEmailOne,
		"delegate_2":              delegateServiceAccountEmailTwo,
		"sub":                     targetServiceAccountEmail,
	}

	resource.Test(t, resource.TestCase{
		PreCheck:                 func() { acctest.AccTestPreCheck(t) },
		ProtoV5ProviderFactories: acctest.ProtoV5ProviderFactories(t),
		ProtoV6ProviderFactories: acctest.ProtoV6ProviderFactories(t),
		Steps: []resource.TestStep{
			{
				Config: testAccEphemeralServiceAccountJwt_withDelegates(context),
				Check: resource.ComposeTestCheckFunc(
					// Assert exact values
					resource.TestCheckResourceAttr(acctest.EchoResourceName, "data.delegates.0", context["delegate_1"].(string)),
					resource.TestCheckResourceAttr(acctest.EchoResourceName, "data.delegates.1", context["delegate_2"].(string)),
					// Assert set
					resource.TestCheckResourceAttrSet(acctest.EchoResourceName, "data.jwt"),
				),
			},
		},
	})
}

func TestAccEphemeralServiceAccountJwt_withExpiresIn(t *testing.T) {
	t.Parallel()

	serviceAccount := envvar.GetTestServiceAccountFromEnv(t)
	targetServiceAccountEmail := acctest.BootstrapServiceAccount(t, "expiry", serviceAccount)

	context := map[string]interface{}{
		"ephemeral_resource_name": "jwt",
		"ephemeral_reference":     "ephemeral.google_service_account_jwt.jwt",
		"target_service_account":  targetServiceAccountEmail,
		"sub":                     targetServiceAccountEmail,
		"expires_in":              "3600",
	}

	resource.Test(t, resource.TestCase{
		PreCheck:                 func() { acctest.AccTestPreCheck(t) },
		ProtoV5ProviderFactories: acctest.ProtoV5ProviderFactories(t),
		ProtoV6ProviderFactories: acctest.ProtoV6ProviderFactories(t),
		Steps: []resource.TestStep{
			{
				Config: testAccEphemeralServiceAccountJwt_withExpiresIn(context),
				Check: resource.ComposeTestCheckFunc(
					// Assert exact values
					resource.TestCheckResourceAttr(acctest.EchoResourceName, "data.expires_in", context["expires_in"].(string)),
					// Assert set
					resource.TestCheckResourceAttrSet(acctest.EchoResourceName, "data.jwt"),
				),
			},
		},
	})
}

func testAccEphemeralServiceAccountJwt_basic(context map[string]interface{}) string {
	return acctest.EchoResourceConfig(context["ephemeral_reference"].(string)) + acctest.Nprintf(`
ephemeral "google_service_account_jwt" "%{ephemeral_resource_name}" {
  target_service_account = "%{target_service_account}"
  payload               = jsonencode({
    "sub": "%{sub}",
    "aud": "https://example.com"
  })
}
`, context)
}

func testAccEphemeralServiceAccountJwt_withDelegates(context map[string]interface{}) string {
	return acctest.EchoResourceConfig(context["ephemeral_reference"].(string)) + acctest.Nprintf(`
ephemeral "google_service_account_jwt" "%{ephemeral_resource_name}" {
  target_service_account = "%{target_service_account}"
  delegates = [
    "%{delegate_1}",
    "%{delegate_2}",
  ]
  payload               = jsonencode({
    "sub": "%{sub}",
    "aud": "https://example.com"
  })
}
`, context)
}

func testAccEphemeralServiceAccountJwt_withExpiresIn(context map[string]interface{}) string {
	return acctest.EchoResourceConfig(context["ephemeral_reference"].(string)) + acctest.Nprintf(`
ephemeral "google_service_account_jwt" "%{ephemeral_resource_name}" {
  target_service_account = "%{target_service_account}"
  expires_in            = %{expires_in}
  payload               = jsonencode({
    "sub": "%{sub}",
    "aud": "https://example.com"
  })
}
`, context)
}
