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
This command drops any existing database. Use only during initial setup!

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

---

## Database Setup and Importing Scenarios (Admin Only)

This guide covers setting up your local ETM databases and importing scenarios using the dump-n-load architecture.

**Important:** MyETM must be set up **first** because it's the OAuth provider for ETEngine and ETModel. Follow the steps in order.

### Initial Database Setup

**Note: If using Docker these steps are not necessary**

#### 1. Install and Start MySQL

```bash
brew install mysql
brew services start mysql
```

#### 2. Set Up MyETM Database (FIRST!)

MyETM is the authentication provider for the entire ETM ecosystem, so it must be configured before ETEngine or ETModel.

```bash
cd myetm
bundle install
bin/rails db:prepare
```

This creates the database, runs migrations, and seeds an admin user. **Save the password displayed in the output:**

```
+------------------------------------------------------------------------------+
|         Created admin user 'Seeded Admin' with password: aBc123Xy         |
|           and email: seeded_admin@localdevelopment.com.                   |
+------------------------------------------------------------------------------+
```

#### 3. Start MyETM

```bash
bin/dev -p 3002
# Or: rails s -p 3002
```

Wait for "Listening on..." before proceeding.

#### 4. Set Up ETEngine Database

```bash
cd etengine
bundle install
bin/rails db:prepare
```

**Warning:** ETEngine requires ETSource to be cloned in the same parent directory. If you get errors about missing datasets, ensure etsource is cloned alongside etengine.

#### 5. Start ETEngine

```bash
bin/dev -p 3000
# Or: rails s -p 3000
```

**Note:** The first time you create a scenario, ETEngine calculates the base dataset (Netherlands). This takes 5-15 seconds. Be patient!

#### 6. Verify Both Servers Are Running

- MyETM: http://localhost:3002
- ETEngine: http://localhost:3000

You should be able to access both URLs in your browser.

### Getting .etm Files for Import

To import scenarios, you first need a `.etm` file. There are two ways to get one:

#### Option 1: Export from MyETM Admin Interface (Recommended)

If you have access to a production or staging MyETM instance:

1. **Log in as admin**

2. **Navigate to admin section**
   - Click "Admin" in the navigation
   - Click "All Scenarios" in the admin menu
   - URL: `https://my.energytransitionmodel.com/admin/saved_scenarios`

3. **Filter for scenarios**
   - Check "Show Featured" to show only featured scenarios
   - Filter by version, end year, or area code as needed

4. **Select scenarios to export**
   - Click checkboxes next to desired scenarios
   - Or click "Select all" to export all filtered scenarios

5. **Export**
   - Click the "Export selected" button
   - A `.etm` file will download (format: `YYYYMMDDHHMM_env.etm`)

6. **Save the file**
   - File downloads to your Downloads folder by default
   - Ready to import to your local environment

### Importing Scenarios

With both servers running and a `.etm` file ready:

#### 1. Run the Import Script

```bash
cd myetm
bin/import-scenarios
```

The script will:
1. Detect any `.etm` file
2. Warn you that import will modify your database
3. Prompt for confirmation
4. Load scenarios via ETEngine API
5. Create SavedScenario records in MyETM
6. Display results and ID mappings

#### 2. Verify the Import

Check the output for:
- Number of scenarios loaded
- Scenario ID mappings (production ID → local ID)
- Any warnings about missing data

#### 3. Access Imported Scenarios

- View in MyETM: http://localhost:3002
- Open in ETModel: http://localhost:3001 (requires ETModel setup)

### Command Options

#### Specify Owner

```bash
bin/import-scenarios --user your.email@example.com
```

By default, scenarios are owned by the first admin user.

#### Handle Duplicates

Control what happens when a scenario ID already exists:

```bash
# Always update existing scenarios (default)
bin/import-scenarios --on-dup update

# Always create new scenarios
bin/import-scenarios --on-dup create

# Prompt for each duplicate
bin/import-scenarios --on-dup prompt
```

#### Search in Different Directory

```bash
# Look for .etm files in db/dumps instead of ~/Downloads
bin/import-scenarios db/dumps

# Or specify exact file path
bin/import-scenarios /path/to/scenarios.etm
```

#### Get Full Help

```bash
bin/import-scenarios --help
```

### Troubleshooting

#### ETEngine Connection Errors

**Problem:** Import fails with "Connection refused" or timeout errors

**Solution:** Ensure ETEngine is running on port 3000:

```bash
cd etengine
bin/dev -p 3000
# Wait for "Listening on..."
```

Check that you can access http://localhost:3000 in your browser.

#### MyETM Not Running

**Problem:** Script error: "Database connection failed" or similar

**Solution:** The import-scenarios script runs within MyETM's context. Ensure the database is set up:

```bash
cd myetm
bin/rails db:prepare
```

#### No Admin User

**Problem:** "No users found in database!"

**Solution:** Re-run the seeds:

```bash
cd myetm
bin/rails db:seed
# Save the password displayed!
# You can then create an account with your own credentials and make yourself an admin if you like!
```

#### Duplicate Scenario Prompts

**Problem:** Import keeps asking about duplicate scenarios

**Solution:** Use `--on-dup update` to automatically update existing scenarios:

```bash
bin/import-scenarios --on-dup update ~/Downloads/scenarios.etm
```

#### File Not Found

**Problem:** "No .etm scenario dump files found"

**Solution:**
- Ensure the file has a `.etm` extension
- Check you're looking in the right directory (defaults to `~/Downloads`)
- Specify the file path directly: `bin/import-scenarios /path/to/file.etm`

### What Gets Imported

Each `.etm` file contains:

**From ETEngine:**
- Slider values (user_values)
- Custom hourly curves
- User sortables
- Area code, end year, privacy settings
- Balanced values

**From MyETM:**
- Scenario title and description
- User permissions (owner, collaborators, viewers)
- Version tags
- Scenario ID history (tracks origin from production)

### Exporting Scenarios to Share

To create a `.etm` file from your local scenarios to share with your team:

1. **Access MyETM admin:** https://my.energytransitionmodel.com/admin/saved_scenarios
2. **Select scenarios** you want to export using checkboxes
3. **Click "Export selected"** button
4. **Share the downloaded `.etm` file** with your team

They can then import it using `bin/import-scenarios`.

### Next Steps

After importing scenarios:

1. Access them in MyETM at http://localhost:3002
2. Set up ETModel to view and modify scenarios in the UI
3. Use imported scenarios as starting points for development
4. Export modified scenarios to share with your team
