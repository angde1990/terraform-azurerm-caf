
output id {
  value     = azurerm_subnet.subnet.id
  sensitive = true
}

output name {
  value     = azurerm_subnet.subnet.name
  sensitive = true
}
