variable "site" {
  description = "FABRIC site for the cluster."
  type        = string
}

variable "ssh_public_key" {
  description = "Public key installed on the nodes."
  type        = string
  default     = "~/work/fabric_config/slice_key.pub"
}

variable "ssh_private_key" {
  description = "Private key matching ssh_public_key, used to reach the nodes."
  type        = string
  default     = "~/work/fabric_config/slice_key"
}

variable "bastion_private_key" {
  description = "FABRIC bastion private key."
  type        = string
  default     = "~/work/fabric_config/fabric_bastion_key"
}
