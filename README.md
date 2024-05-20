# ViaThinkSoft UserDetect2

## What is UserDetect2?

UserDetect2 is a program that allows the user to execute different programs depending on their current environment (e.g. MAC addresses, user name or computer name), so that a single executable file, e.g. shared over a network drive, a flash drive or external hard disk, can perform tasks for different work stations. The environment identifications can be extended by plugins.

Note: "testuser" is the predecessor of UserDetect and also included in this GitHub repo.

## Usage example

You have an external hard disk which you use for a daily backup with a backup tool (e.g. Microsoft RoboCopy).

You use this external drive to perform backups for different computers.

Additionally, you want to decide if the computer should be shutdown after the backup, or not. (Can be useful if you leave the computer alone, while the backup is performing)

If you have 2 computers with the names “JohnPC” and “JohnLaptop”, then you would probably need 4 batch files:

 1. E:\JohnPC\backup_no_shutdown.bat
 2. E:\JohnPC\backup_shutdown.bat
 3. E:\JohnLaptop\backup_no_shutdown.bat
 4. E:\JohnLaptop\backup_shutdown.bat

If you accidently start the wrong batch file, the backups will be inconsistent, and there may be data loss.

But if you use UserDetect2, you could create following Task Definition File:

    [NoShutdown]
    Description=Run backup without shutdown
    ComputerName:JohnPC=JohnPC\backup_no_shutdown.bat
    ComputerName:JohnLaptop=JohnLaptop\backup_no_shutdown.bat
    
    [Shutdown]
    Description=Run backup and shutdown
    ComputerName:JohnPC=JohnPC\backup_shutdown.bat
    ComputerName:JohnLaptop=JohnLaptop\backup_shutdown.bat

In this case, you would only need to run “E:\UserDetect2.exe” (maybe even use it as AutoRun application, if you are working with Windows Vista or previous versions of Windows) and then select if you want to perform a backup with or without shutdown. UserDetect2 will select the correct batch file for you.

## Documentation

In the [documentation](https://github.com/danielmarschall/userdetect2/blob/master/UserDetect2/Documentation.pdf) you can read more about:

- Command line usage and return codes
- Task Definition File (UserDetect2.ini)
- Troubleshooting
- Plugin development / SDK
- Migration from the software "testuser" (predecessor)
- Known issues
- Changelog
- Contact the author

## License

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by  the Free Software Foundation; either version 2 of the License, or (at your option) any later version.
 
This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
