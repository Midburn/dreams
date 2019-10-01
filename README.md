[![Build Status](https://travis-ci.org/Midburn/Dreams.svg?branch=master)](https://travis-ci.org/Midburn/Dreams)

# Midburn Dreams

This is a platform to plan co-created events. It was originally created for Urban Burn Stockholm in 2016 and was then used for The Borderland in 2016 and For Midburnerot 2016. It's being continuously and sporadically developed by a rag-tag team and will probably always be in beta. This version was the adoption of the Midburn - Israeli regional community. You can see it in action here: 
http://dreams.midburn.org
and the Midburnerot version:
http://dreams.midburnerot.com
and the original system here:
http://dreams.theborderland.se/

## To get started

* Install ruby 2.3.1 (or any ruby will probably work).
* Install postgres - `brew install postgresql`
* Install imagemagick - `brew install imagemagick`
```
    gem install bundler # if needed
    bundle install
    bundle exec rake db:migrate
```
To get all the deps and the database set up properly. To start the server:

    bundle exec rails s

Now rails will listen at `localhost:3000` for your requests.

Go to `dreams/new` to create a new dream and to `/dreams` to see a list of camps.

## There are tests

Run them with:

    bundle exec rspec spec

## Database

Currently sqlite is used as the local database. We will stick to this in development but set up
Postgres in production. Install sqlite with your favourite package manager and you should
be up and running right away.

## Mail

In development mode [mailcatcher](http://mailcatcher.me/) is configured to catch emails
locally for easier testing.

## Active Admin
Users and creations can be administrated with Active Admin. 
After install, run:
```
bundle exec rake db:migrate db:seed
```
Then naviagte to `http://localhost:3000/admin`
and use `admin@example.com` and `password`

## Creating your first user
* Navigate to [http://localhost:3000/admin/tickets/new](http://localhost:3000/admin/tickets/new)
* Enter your phone number and email
* Then create your user with the same phone number and email here: [http://localhost:3000/users/sign_up](http://localhost:3000/users/sign_up)

## User types in the system
The system user types are: anonymous users, normal registered users, guides, admins

You can set yourself as a guide and admin in the /admin panel

Guide and admins see buttons on the dream page and info that normal and guests users dont have access to.
Guide and admins can close/open granting and edit dreams

## Ticket ID Import

Ticket ids are imported from a two column csv file of IDs which can be set to any url using `IMPORT_CSV_URL` env variable
Rake task is in lib/tasks/import.rake and is run with "bundle exec rake import"

## Ticket verifier through TixWise

We've added an optional verification through tixwise - you need to aquire an API from them and then set `TICKETS_EVENT_URL` ENV variable to a url such as:
```
https://www.tixwise.co.il/he/api.xml?USER=useremail@gmail.com&PASS=userpass&TOKEN=api_token&VERSION=1.0&ACTION=event_listPurchases&id=event_id
```
Make sure you change the username, password, token and event id

## Production

#### Schema changes
##### Heroku
After any schema changes make sure you run
`heroku run rake db:migrate --app=YOUR_APP`
Then you might need to restart the instance with
`heroku run restart --app=YOUR_APP`
##### midburn-k8s
The docker image is built to run migration on startup, This means no extra actions are required to run migrations.

#### Email
To get the mailing system working on Heroku -
* Add Sendgrid as a Resource (this will automatically set SENDGRID_USERNAME & SENDGRID_PASSWORD)
* Update the email from using:
`heroku config:set EMAIL_FROM=galbra@gmail.com`

#### Image upload
To set up the image upload make sure to create the S3 user and set the following heroku env variables
* `S3_BUCKET_NAME`
* `AWS_ACCESS_KEY_ID`
* `AWS_SECRET_ACCESS_KEY`

From our experience, if the s3 bucket didn't exist - it was automatically created on first time upload in case your user have write access to s3.

## Drive integration

#### Google apps script
We've added the ability to integrate to google drive.
on every new dream that is being created - a google apps script create a folder with the dream id, dream name, and give access to the dream owner. it also coppies some needed files to that folder and save the folder info and specific file ids to allow the user to edit them directly on google drive.

It require an google apps script published as API execution
and also the following env vars:
* `GOOGLE_APPS_SCRIPT`
* `GOOGLE_APPS_NAME`
* `GOOGLE_DRIVE_INTEGRATION=true`
* `GOOGLE_APPS_SCRIPT_FUNCTION='function-name'`
* `GOOGLE_CLIENT_SECRETS=content_of_client_secret.json`

1.Set the env `GOOGLE_DRIVE_INTEGRATION=true`
2.Start with enabling the API on the google console. getting a token.
Then set the `GOOGLE_CLIENT_SECRETS` variable
3.Then go to https://console.developers.google.com/apis/credentials?project=YOUR-PROJECT-ID
and copy the name of Oauth2 client Id - this will be the `GOOGLE_APPS_NAME` env variable
4.Then inside your script there is the actual function name to call it is usually `createDream` - this is the `GOOGLE_APPS_SCRIPT_FUNCTION` env
5.Finally leave the `GOOGLE_APPS_SCRIPT_TOKEN` empty. and then after you run your app for the first time. check the logs. you will see a url. this url will contain the actual token. then set the `GOOGLE_APPS_SCRIPT_TOKEN` to be that token

## Spark support
More about spark here - http://github.com/midburn/spark
Spark is a "burn in a box" - we use the spark API to prevent users from Registering into multiple system.
So anyone who has a Midburn profile could register to the system using that profile credentials.

Set it using the following env var:
`SPARK=true`
`SPARK_URL=http://sparkstaging.midburn.org/api/userlogin`

Also one request was that the spark would know when we update the list of people - make sure you set the `SPARK_PEOPLE_URL`


## Ability to Show/Edit Point of Contact
We've added the ability to show a contact person from art-department for the dream-creator in the dream page. This field is editable by admin/guide users only.

You will need to set the following env var:
* `SHOW_POINT_OF_CONTACT=true`

## Ability to Show/Edit Safety File Comments
We've added the ability to show safety file comments for the dream-creator in the dream page. This field is editable by admin/guide users only.

You will need to set the following env var:
* `SHOW_SAFETY_FILE_COMMENTS=true`

## Ability to Disable Editing for Dream-Creator
If at some stage you will want to prevent the dream creators from updating a dream you can set this global env variable to do so:
* `DISABLE_EDITING_DREAM=true`

## Ability to Hide 'Create Dream' Button
If at some stage you wish to hide the 'Create Dream' button (where dream-creation is still available by a direct link) you can set this global env variable to do so:
* `HIDE_CREATE_DREAM_BUTTON=true`

# Events
Each year we have new dreams.
We need to update each year by setting the `default_event` parameter in the `application.rb` file

If you just integrated the events be sure to run
`rails console`
OR
`heroku run rails console --app=YOUR_APP`
Then set all events to your event - for example for midburn2017 we call
`Camp.all.each do |camp| camp.update(event_id:'midburn2017') end`

# midburn-k8s
##### Rails Console
Connect to the desired environment (see https://github.com/Midburn/midburn-k8s#quickstart)
  - `docker run -it --entrypoint bash -e OPS_REPO_SLUG=Midburn/midburn-k8s orihoch/sk8s-ops`
  - `gcloud auth login`
  - `source switch_environment.sh staging`
run `kubectl exec -ti `kubectl get pods | grep "dreams-" | awk '{print $1}'` -- rails c`
##### Update Environment Variables
Update the dreams section here with the new values:  https://github.com/Midburn/midburn-k8s/blob/master/environments/staging/values.yaml#L101  (or similar file in the `production` environment)
Some values are hardcoded in the external-chart (https://github.com/Midburn/midburn-k8s/blob/master/charts-external/dreams/templates/dreams.yaml) , If possible those should be moved to the environments/../values.yaml before updating them.
##### Updating production version
To update the version in midburn-k8s production one should create a new "release" on github and a new production version will be deployed automagically. If we want to rollback we can update the release number on https://github.com/Midburn/midburn-k8s/blob/master/environments/production/values.auto-updated.yaml#L6

# Trouble shooting

## macOS High Sierra

Due to changes in the OS, the following needs to be set before running the server locally:

```sh
export OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES
```

Per [Why Ruby app servers break on macOS High Sierra and what can be done about it](https://blog.phusion.nl/2017/10/13/why-ruby-app-servers-break-on-macos-high-sierra-and-what-can-be-done-about-it/)
