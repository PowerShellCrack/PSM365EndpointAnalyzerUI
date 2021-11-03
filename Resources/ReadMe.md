Docmuentation about the variables inside the UI created in XAML for the M365 endpoint tool

#General 

|Name | x:Name | Description|
|-----|--------|------------|
| Close | closeApp | Button to close the application |
| Progress bar | progressBar | Bar to show the progress of the test connections |
| Progress number | progressNumber | Label to show the % of the progress |

#Selector tab
|Name | x:Name | Description|
|-----|--------|------------|
| Intune Endpoints | intuneEndpoints | Selector if the user want to test Intune Endpoints only |
| Exchange Online | exchangeOnline | Selector if the user want to test Exchange online only |
| Sharepoint Online | sharepointOnline | Selector if the user want to test Sharepoint online only |
| Teams | teams | Selector if the user want to test Microsoft Teams only |
| Microsoft 365 Common and Office Online | m365Common | Selector if the user want to test Microsoft 365 Common and Office Online |
| Full Microsoft 365 | fullM365 | Selector if the user want to test all services listed above | 
| Domains | domains | Check if want to test domains |
| IPv4 | ipv4 | Check if want to test IPv4 |
| IPv6 | ipv6 | Check if want to test IPv6 | 
| Required endpoints | requiredEndpoints | Select if want to evaluate only the required endpoints |
| Full (Required + Optional) | fullEndpoints | Select if want to evaluate all endpoints |
| Offline mode | offlineMode | Check if there is no internet connection to GitHub and MSFT Docs | 
| Run | run | Run button to start the execution | 

#Domain tab
|Name | x:Name | Description|
|-----|--------|------------|
| Domain table (ListView) | domainTable | Domain table to print connectivity errors to urls |
| Notification label | domainNotificationLabel | Notification label to let the user know about the status of the domain test connection | 
| Back button | domainBack | Back button to return to the status page |

#IPv4 tab
|Name | x:Name | Description|
|-----|--------|------------|
| IPv4 table (ListView) | ipv4Table | Domain table to print connectivity errors to IPv4 |
| Notification label | ipv4NotificationLabel | Notification label to let the user know about the status of the IPv4 test connection | 
| Back button | ipv4Back | Back button to return to the status page |

#IPv6 tab
|Name | x:Name | Description|
|-----|--------|------------|
| IPv6 table (ListView) | ipv6Table | Domain table to print connectivity errors to IPv6 |
| Notification label | ipv6NotificationLabel | Notification label to let the user know about the status of the IPv6 test connection | 
| Back button | ipv6Back | Back button to return to the status page |

#Summary tab
|Name | x:Name | Description|
|-----|--------|------------|
| Endpoint succesfull number | endpointSuccesfull | Text to print the # of succesfully tested endpoints |
| Endpoint falied number | endpointError | Text to print the # of fail tested endpoints | 
| Full report | fullReport | Select if the user wants to download the full report of the test (sucesfull and failed tests) |
| Failed report | failedEndpoints | Select if the user wants to download only the failed connections |
| Download CSV | downloadCsv | Button to download the report in CSV |
| Download xlsx | downloadXlsx | Button to download the report in xlsx |
| Back button | summaryBack | Back button to return to the Option tab |

