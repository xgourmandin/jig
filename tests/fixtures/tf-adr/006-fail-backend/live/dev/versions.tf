terraform {
  backend "gcs" {
    bucket = "state"
  }
}
