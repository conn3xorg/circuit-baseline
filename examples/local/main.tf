variable "port" {
  type    = number
  default = 2222
}

module "baseline" {
  source = "../.."

  hosts                = { box = "127.0.0.1" }
  ssh_port             = var.port
  ssh_private_key_file = "./id_ed25519"
  ssh_known_hosts_file = "./known_hosts"
  timezone             = "Europe/Dublin"

  # A container can't set the clock, so chronyd only tracks it.
  chrony_set_clock = false
}
