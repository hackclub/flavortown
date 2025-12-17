# flavortown

what's cooking in the hack club kitchen :fire:

## non-exhaustive list of setup steps

### docker

me and the homies love docker, and it makes it stupid simple, so its highly recommended to use docker to make your life easier.

1. clone it (duh)
2. you most likely want a database here, so you can run that with this:

```bash
docker compose up
```
3. visit your personal flavortown at http://localhost:3000. if you get an error about pending migrations, click "run pending migrations".
3. grab a monster

**random commands you might need**

if you just need to run a command once (eg test migrations or whatever) here is how

```bash
docker compose run web bin/rails db:migrate # please dont do this if you are hooked up to prod
docker compose run web bin/rails bundle install
docker compose run web bin/lint
```

if its giving you a file not found error and you are on windows, try running these commands. They switch line endings to lf (linux) ones

This will reset all your code!

```
git config --local core.autocrlf false
git rm --cached -r .   
git reset --hard
```



## i hate docker

weirdo, but okay, you gotta figure out how to get postgres running yourself bucko

1. double check your `.env` file to make sure its pointed at your database
2. setup the db

   ```bash
   bin/rails db:prepare
   ```

3. start the dev server

   ```bash
   bin/dev
   ```

4. have a fire extinguisher at the ready
