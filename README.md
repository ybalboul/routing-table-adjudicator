# routing-table-adjudicator
Script I made at work that adds/removes ip addresses to a routing table, the ip addresses are read in from a lst file or can be added/removed individually.

Adding individually
> ./routing_table_adjudicator -A [ip address] -g [gateway address]

Removing
> ./routing_table_adjudicator -R [ip address] -g [gateway address]

Adding via a lst
> ./routing_table_adjudicator -a [lst file path] -g [gateway address]

Removing
> ./routing_table_adjudicator -r [lst file path] -g [gateway address]

Script must be ran as sudo.
