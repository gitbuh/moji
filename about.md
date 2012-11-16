# Moji #

An IRC bot for Mojirans.

## Commands ##

The bot composed of plugins, which expose commands.

### Feed ###

Reports (parts of) the JIRA / Confluence activity feed to the IRC channel.

 - __!feed__: Show all activity to the channel.

 - __!feed off__: Stop showing activity to the channel.

 - __!feed *filter*__: Show activity matching *filter* to the channel.

### Search ###

Search for tickets in the JIRA.

 - __!filter *name*__: Show the results of a named filter.

 - __!find *stuff*__: Find stuff using a simple text search.

 - __!more__: Get the next page of results for your last query.

 - __!search *JQL*__: Search using JQL syntax.

### Op ###

Bot operator commands. These are currently undocumented; see the [source](#file_moji/plugin/op.pm).

