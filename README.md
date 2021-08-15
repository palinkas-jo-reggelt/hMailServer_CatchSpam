# hMailServer_CatchSpam
 
CREATE TABLE hm_catchspam (
  timestamp datetime NOT NULL DEFAULT current_timestamp(),
  domain varchar(25) NOT NULL,
  hits int(1) NOT NULL,
  safe int(1) NOT NULL,
  PRIMARY KEY (domain)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

## Requirements

RvdH's DNS resolver (https://d-fault.nl/files/DNSResolverComponent_1.3.exe.zip)
RvdH's Disconnect.exe (https://d-fault.nl/files/Disconnect.zip)


## Instructions

1) Run PublicSuffixLoad.ps1 to create vbs public suffix list

2) Create MySQL table above

3) Add contents of EventHandlers.vbs to your hMailServer EventHandlers.vbs

4) Place contents of www folder into your webserver root

5) Copy config.php.dist to config.php and edit variables

6) Let hMailServer swat away spammers
