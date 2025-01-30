# PagerSync

A customer had a requirement to populate the "othermails" attribute for certain hybrid entra users who were NOT mail enabled with an external email address

To do this we picked an attribute for the AD User (pager) and added the external email address for each user to that attribute.

It would have been nice to use Entra Connect Sync to sync the attribute for us but unfortunately 'Othermail' is not an attribute we can target in the sync rules.

This script is designed to check an ad group containing the users in question, check to see if there is a value in 'pager' on the ad user and then overwrite (not add) the entra user 'Othermail' attribute with this email address

The script is work in progress and uses an app registration with application graph permissions to run unattended.  This should be moved to use certificate authentication once in production.

To do: configure the script to send an email on completion with the log file attached.