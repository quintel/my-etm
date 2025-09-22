# MyETM

MyETM is the central hub of the [Energy Transition Model (ETM)](http://energytransitionmodel.com), allowing users to view saved scenarios and collections across different versions.
To run MyETM locally, you will need to set up the entire ETM ecosystem, which consists of:
    MyETM: The central hub for scenario management.
    ETEngine: The main calculation system and API.
    ETModel: The front-end for creating scenarios with a user interface.
    ETSource: The repository containing source data required by ETEngine.

## License

MyETM is released under the [MIT License](LICENSE.txt).

## Installation with Docker

MyETM, ETEngine, and ETModel are configured to run with Docker (via Docker Compose), simplifying
dependency management. This guide assumes that Docker is already installed and configured on your machine.

### Clone the repositories

Ensure all ETM components reside in the same parent directory by cloning the repositories:
```
git clone https://github.com/quintel/etengine.git
git clone https://github.com/quintel/etmodel.git
git clone https://github.com/quintel/etsource.git
git clone https://github.com/quintel/myetm.git
```

This will create a directory with the following structure:
```
├─ parent_dir
│  ├─ etmodel
│  ├─ myetm
│  ├─ etsource
│  └─ etengine
```

### Encrypted Datasets (For Quintel Staff Only)

ETSource requires a password to decrypt certain datasets. To set this up:
    1. Create a .password file in the ETSource directory.
    2. Obtain the password from the "Quintel → Shared" 1Password vault.
    3. Save the password inside .password.

```
├─ etsource
│  ├─ .password  # <- Place password here
│  ├─ carriers
│  ├─ config
│  ├─ datasets
```

Public users will not have access to encrypted datasets and should use alternative datasets as indicated in the documentation.

### Running MyETM

#### Step 1: Build MyETM Docker Images
```sh
cd myetm
docker-compose build
```

#### Step 2: Install Dependencies and Seed the Database
```sh
docker-compose run --rm web bash -c 'chmod +x bin/setup && bin/rails db:drop && bin/setup'
```
⚠️ This command drops any existing database. Use only during initial setup!

For updates, install new dependencies using:
```sh
docker-compose run --rm web bin/setup
```
This command is idempotent and can be run anytime as needed.

#### Step 3: Start MyETM
```sh
docker-compose up
```
Once running, MyETM will be available at [http://localhost:3002](http://localhost:3002).

## Installation without Docker

Installing MyETM on a local machine can be a bit involved, owing to the
number of dependencies. Assuming you can run a 'normal' rails application on your local machine,
you have to follow these steps to run MyETM.

1. Install the "Graphviz" library
   * Mac users with [Homebrew][homebrew]: `brew install graphviz`
   * Ubuntu: `sudo apt-get install graphviz libgraphviz-dev`

2. Install "MySQL" server
   * Mac: Install latest version using the [Native Package][mysql] (choose the 64-bit DMG version), or install via brew: `brew install mysql`
   * Ubuntu: `sudo apt-get install mysql-server-5.5 libmysqlclient-dev`

3. Clone this repository with `git clone git@github.com:quintel/myetm.git`

4. Run `bundle install` to install the dependencies required by MyETM.

5. Clone a copy of [ETSource][etsource] –– which contains the data for each
   region:
   1. `cd ..; git clone git@github.com:quintel/etsource.git`
   2. `cd etsource; bundle install`

6. Create the database you specified in your "database.yml" file, and
   1. run `bundle exec rake db:setup` to create the tables and add an
      administrator account –– whose name and password will be output at the end –– OR
   2. run `bundle exec rake db:create` to create your database and
      contact the private Quintel slack channel to fill your database with records from staging server

7. You're now ready-to-go! Fire up the Rails process with `rails s -p 3002` or better `bin/dev -p 3002`.

8. If you run into an dataset error, check out this
   [explanation](https://github.com/quintel/etsource#csv-documents "Explanation on etsource CSV files") on CSV files


## Connecting to ETEngine, ETModel and Collections
After setting up MyETM, configure it to communicate with ETEngine and ETModel:
1. Log in to MyETM as an administrator.
2. Navigate to **Your Applications** in the admin panel.
3. Create new applications for **ETEngine (Local)**, **ETModel (Local)** and **Collections (Local)**.
4. Copy the generated configuration into `config/settings.local.yml` for both ETEngine and ETModel.
   Copy it into `.env.local` for Collections.
