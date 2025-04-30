locals {
  # Transform availability zones from list to comma-separated string
  availability_zones = length(var.availability_zones) > 0 ? join(",", var.availability_zones) : []
}