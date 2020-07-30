# Powershell tools

In this repository I want to share you some Powershell scripts to made easy administration Windows Servers and Work stations in small organisations.

Desription some of this:

### Replication info
I know some tools for monitoring Replication in MS Hyper-V, but basic in my opinion is powershell + telegram.
This script polls the necessary hosts once a day (by default) and if it finds errors, send a message about it to the telegram channel.

![example message](/images/repl_nfo.jpg)

### Shrink SQL Log files
Very often, on MS SKL servers in 1C databases, log files grow to unimaginable sizes, and if there are few databases on the server, it is not difficult to do the procedure for cleaning the log files by hand. This script will help if you have several servers and they do not have one database. Since the operation with data in the script there are requests for confirmation of actions. Be careful with your data.

![shrn_sql](/images/shrn_sql.jpg)

### Hyper-V Create VM
