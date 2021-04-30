# mcft-template

This is a template for scheduled powershell scripts that generate Motor Carrier Tax Filing files.

## What is this?

This is about handling Motor Carrier Tax Filing using TMW. I won't cover all of the aspects of these topics as, if you are looking at this project at all, you probably already understand these things. I'll just talk about my specific situation while creating this.

We deliver fuel using trucks, so we are a Motor Carrier. You have to be registered to do this sort of thing and in some states you must file taxes. You aren't paying taxes, but you have to report on what you carry.

Searching google for "motor carrier fuel tax" or "motor carrier tax filing" will get you some information on this process. It varies state by state.

This project is a template to handle these filings using a query to pull data from a system called TMW Suite. You can read more about it by searching google for "trimble tmw suite".

Technically this harness/structure would work against any system, but it is currently setup to use TMW.

In our case, the 'default' setup is a file is generated and emailed to someone who will do the filing with the state as each state has it's own system, format, and way of filing.

## How does it work

I will go through the files and describe what they are. I'll start simple and end up with the more complicated items.

### .gitignore
You don't need this file, but I wanted a base version in the template. See [this documentation](https://git-scm.com/docs/gitignore) if you don't know what a .gitignore file is. This file is the same for most of our tax feeds.

### README.md
A readme that describes what this job is. I deploy one with every job that has the custom information for that particular job. This way a support person can simply look in that folder and determine what this job is. You don't have to have this file, but I think deploying this helps someone 5 years from now who is wondering what the point of this job is. This default file will help someone, but I customize this for each implementation with references for that particular state, table/field mappings, and any other relevant info I think will be important for, at a minimum, my future self.

### spec.msg
This is simply a saved email message that may contain the contents of the specification discussion when the feed was first setup. Sometimes this may not exist if there was no email thread about it, but I generally find it easier to just consolidate all of the email threads related to this feed and save them as one message so any future person can review them. I typically just consolidate those emails, forward them to myself, drag and drop the message from outlook, and rename it to spec.msg for every job. This saves me the need to change the file name in the deploy script because they are all using the same file names.

### deploy.ps1
This is a helper script for deploying the jobs to a windows server using windows scheduler. It assumes you have access to deploy the files and schedule jobs remotely. You can customize the server, destination folder, and the file list to deploy. It will treat the current folder as the target folder to deploy to, so if you have forked this and cloned into a folder for filing for indiana and the folder is called filing-indiana, it will attempt to create that folder in c$\jobs on the target folder as is. By default, I generate files on the 15th of every month at 10am. This file can technically be anything, or perhaps be completely absent if there is an automated process. I typically hand deploy these jobs as they don't change much, and I use this script to do the deployment if there are updates.

### get-data.sql
This is the sql file used to query the database for the data in question. The field names output are important and if changed require updates in other files to compensate. Since tax feeds have to have *all* of the information in them, normally, with no exceptions we have to include all of the null values and missed joins so we can check for them later. This can be adjusted as needed, but we basically use the same structure even though some of the fields are not required by certain states. If you are implementing this in your system, you will likely need to update key values like the commodity classes or various notes that system depending on how you map the values. We've been a customer for several decades, so our system is probably unlike a pristine new system. But as long as this query returns the data needed, it will work. Some of the mappings in this file could be turned into config, but for us we normally need some customization here and it's not really worth the work to turn this into a file that is identical normally. At a minimum the commodity mappings and the state need to be changed per job.

### settings.json
This is the settings file for the job. By default the jobs generate files and send emails out so the file names are configured here as well as the email info. Also included here are company type mappings and the tests that are run on all of the freight items that will be reported. For filing purposes, like with any tax filing I suppose, things must be perfect. There is no allowance for any bad data and anything that is bad will require an amendment later to correct. So we test all of the data as it comes out of the system to ensure it is good. The tests are configurable by field for the freight so you can put in the field you want to test and a regular expression that it must pass. If you pickup or drop off fuel multiple times at the same place in a given month any issue with that company (the actual place is stored for us in TMW as a company regardless of the type of location) will cause multiple issues because each of the freight lines will fail. To combat this error spam, we run company error tests, and generate those unique companies using the company type mappings. Typically this is just the id, name, maybe tax ids or addresses, etc. These lists are then run against the company type tests that. Tests are listed with a type of 'freight' which is run against all freight lines, or some type of company which will only have the unique versions of that company tested. Typically each state will have it's own tests as some states do not need you to send the same fields. One state may not need consignee address, for example, only name, state, and taxid.
### job.ps1
This is the file that is actually invoked by the scheduled job. It includes modules that must be imported and depends on a number of common modules that make up the majority of the 'code' in these jobs. It depends on settings.json. So while each job contains possibly some custom code in job.ps1 and a single custom ConvertTo-TaxFile.psm1 module, most of the code is identical and exists in other installed modules. The default process will use the following modules. You can reach more about these on [PowerShell Gallery](https://www.powershellgallery.com/), but I'll include a brief description below:

- Add-PrefixForLogging - this adds some datetimestamp and tick information for logging, uses alias 'l'.
- Get-DataTableFromSQL - this is what we send the sql file to and it will return a datatable, this is not actually used in this job, but is a dependency for Get-FilesForMCTF
- Get-FilesForMCTF - this is what actually generates the files to be sent out.
- Send-FileViaEmail - this is a basic wrapper for send-mailmessage

This file will output to the screen as well as a log using tee-object. It follows a simple structure of 'get the data' and then 'use the data' which in most cases is just going to generate files and send them out. Previously there was a cleanup step, that would purge files, but we no longer automatically delete any files for taxes and manually archive them if needed. This is on something like a 'once per decade' manual review.

### ConvertTo-TaxFile.psm1

Each state has it's own custom file generation process. Get-FilesForMCTF requires this cmdlet to be in the global space or else it will fail eventually when it goes to generate the file. It will still generate the data files and the test results, but without this command, you can't generate the actual file to send to the state.

Most states require edi files and you can see a sample mapping in this template that is based on the filing for KY. But some states use csv, xlsx, web service auto filing, etc. This customization will always be in this file.

Typically this file will simply generate the file specified in settings.json as the global file name. That file is what will be used by Get-FilesForMCTF as a the file name to compress everything and that compressed file is what will be sent out.

This dependency is a little fuzzy with using a module as the dependency map is not clear in the module manifest, but this greatly simplified the jobs because we only have this custom output formatter in each job.

## How can I use this

Simple. Fork it, clone it, or click the 'use this template' button. Then update the files as needed.

## Is it really that simple?

Yes, but the 'updating' is custom. For most states the process goes something like this:

- fork/clone/template the repo
- update readme with appropriate info for the state
- update and test get-data.sql with the appropriate state info and commodity mappings
- update settings.json with appropriate file name, email settings, and tests
- update ConvertTo-TaxFile.psm1 with appropriate formatting logic to generate the tax file itself

There are some states for which this job requires more modification. AL, for example, requires live filing with their WS and for an implementation of that feed we have a custom version of the mail module because we include the web service response in the body that is emailed out. We also have custom function for doing the filing prior to emailing out the response. The filing takes place automatically so if there are exceptions generated by testing, an amendment needs to be filed. This is different than other jobs where the filer receives the test results and the file at the same time and so they can simply request that the file be regenerated.

## Any thing else to know?

By default, this job generates data for the previous month. You can see the log files will generate using get-date with a -1 month and in the get-data.sql there is an offset by one month from today. In the event a previous month needs to be run, the dates need to be udpated appropriately in the sql and the files may need to be renamed. The mappers generally use a period date in the sql to determine the period so simply specifying a previous date will take care of that for the mapping. Many states require various changes for filing amendments, but *mostly* it just means changing a line in the header of the edi file so we do not have a special process for that as we just update the file after it is generated. For KY, for example, the BTI line is just changed at the end from ~00\ to ~~6S. The state documentation has to be consulted for specifics.

I think the only other item worth noting is related to powershell modules and loading them. Generally these jobs are running and then ending, but when testing you may be wanting to use the same console session. Depending on your module and powershell version, reimporting the module may be spotty. So I always kill the process after each instance while testing or call it like the job would with powershell job.ps1 so it does a fresh import each time. Obviously there is only one module that is loaded in this case, but that is also frequently the module that I am needing to refresh. So sometimes if I am doing a 'lot' of development, I may rename that file to ps1 and . include it instead of importing it as a module temporarily.

I don't have to do this much as we are not adding and removing states we work in frequently and once a state is written, they do not make many changes to their process or formats, but it is worth noting.

## Why is there a template for this?

We had an occassion to rewrite all of our feeds, and in that process I converted them to using modules and using a template, so I published it in case anyone else is looking for something similar. This process has worked great for us for years. It's pretty simple, but it's easy to maintain and now that it is modularized there is even less of a customization footprint on each job.