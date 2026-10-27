variable "hosts" {
  type        = any
  description = "Hosts to configure: a map of names to addresses, or to host objects with an address and optional host_key, user, port, private_key_file or jump_hosts."
}

variable "ssh_user" {
  type        = string
  default     = "root"
  description = "User to log in as."
}

variable "ssh_port" {
  type        = number
  default     = 22
  description = "SSH port."
}

variable "ssh_private_key_file" {
  type        = string
  default     = null
  description = "Path to a private key. When null, Conn3x uses the SSH agent."
}

variable "ssh_known_hosts_file" {
  type        = string
  default     = null
  description = "known_hosts file to check host keys against. When null, ~/.ssh/known_hosts."
}

variable "ssh_become" {
  type        = bool
  default     = false
  description = "Run commands as root through sudo."
}

variable "timezone" {
  type        = string
  default     = "UTC"
  description = "IANA time zone, such as Europe/Dublin."
}

variable "chrony_set_clock" {
  type        = bool
  default     = true
  description = "Let chronyd set the system clock. Set to false in containers, and on VMs whose hypervisor sets the clock, so chronyd runs with -x."
}

variable "sysctl" {
  type        = map(string)
  description = "Kernel parameters to set, by name."
  default = {
    "net.ipv4.tcp_syncookies"                = "1"
    "net.ipv4.conf.all.accept_redirects"     = "0"
    "net.ipv4.conf.default.accept_redirects" = "0"
    "net.ipv4.conf.all.send_redirects"       = "0"
    "net.ipv4.icmp_echo_ignore_broadcasts"   = "1"
  }
}

variable "sshd_settings" {
  type        = map(string)
  description = "sshd settings to write to /etc/ssh/sshd_config.d/00-conn3x-baseline.conf, by keyword."
  default = {
    PasswordAuthentication = "no"
    PermitRootLogin        = "prohibit-password"
  }
}
