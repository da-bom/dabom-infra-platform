terraform {
  cloud {
    organization = "dabom"

    workspaces {
      name = "dabom-infra-platform"
    }
  }
}
