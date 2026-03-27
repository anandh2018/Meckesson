# Instruction to check-in files under 'etc' folder

**!!! Make sure no password (plain or encrypted) is checked into GitHub repository. !!!**

1. Clone/Checkout the repository where you want to add the files. For example, if you are currently working on 'CSDE_app_COCRPT', clone/checkout this repository.
  
2. In cloned/checked out repository, create a new `dev` branch from '**develop**' branch. For example, if you are working on RHPD-100, create a 'dev' branch called 'dev-RHPD-100'

3. After creating a new branch, go to 'etc' folder (*make sure you are on newly created branch*)

4. Create '*dev*', '*qa*' and '*prod*' folders under 'etc' folder
 
    **Dev**
    
    * Go to newly created 'etc/dev' folder. 
    * FTP files from DSDEV product 'etc' folder. For example, if the current repository is 'CSDE_app_COCRPT', get files from DSDEV:/ds/env/dev/COCRPT/common/etc folder to local 'CSDE_app_COCRPT/etc' folder
    * Remove any password reference from 'build_config.xml' and other 'filed' configuration files.


    **QA**
    
    * Go to newly created 'etc/qa' folder. 
    * FTP files from DSQA product 'etc' folder. For example, if the current repository is 'CSDE_app_COCRPT', get files from DSQA:/ds/env/qaqc/COCRPT/common/etc folder to local 'CSDE_app_COCRPT/etc' folder
    * Remove any password reference from 'build_config.xml' and other 'filed' configuration files.


    **Prod**
    
    * Go to newly created 'etc/prod' folder. 
    * FTP files from DSPROD product 'etc' folder. For example, if the current repository is 'CSDE_app_COCRPT', get files from DSPROD:/ds/env/prod/COCRPT/common/etc folder to local 'CSDE_app_COCRPT/etc' folder. If you don't have access to production or permission to read the production 'etc' folder, reach out to *Larry Spiwak* or *Reed Caldwell* to get files from production 'etc' folder.
    * Remove any password reference from 'build_config.xml' and other 'filed' configuration files.


5. After password update, `add` and `commit` the changes to `dev` branch (dev-RHPD-100).
   
6. From `dev` branch (dev-RHPD-100), create a `Pull Request` to `Merge` the update to '**develop**' branch.
   
7. Create a new `qa` branch from '**develop**' branch. For example, if you are working on RHPD-100, create a 'qa' branch called 'qa-RHPD-100'
   
8. From `qa` branch (qa-RHPD-100), create a `Pull Request` to `Merge` to '**main**' branch.


