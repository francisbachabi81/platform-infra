# basics
plane           = "nonprod"
location        = "Central US"
subscription_id = "aab00dd1-a61d-4ecc-9010-e1b43ef16c9f"
tenant_id       = "dd58f16c-b85a-4d66-99e1-f86905453853"

# names
product = "pub"
region  = "cus"

# shared network rg
shared_network_rg = "rg-pub-np-cus-01"

# front door
create_frontdoor = true
sku_name         = "Standard_AzureFrontDoor"

# tags
tags = {
  product = "pub"
}