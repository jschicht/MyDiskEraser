So I decided to create my own disk eraser, and document how to do so. DBan (Darik's Boot and Nuke) is a popular and good choice, and I have used it before. But, I wanted to show myself it is not rocket science to create a specialized bootdisk for erasing/overwriting internal harddisks. In my case, since it is by far the most easy to customize, I wanted to use WinPE as a base. WinPE 3.1 to be exact (based on Windows 7 SP1). So I needed a tool to do the actual disk erasing, and I decided to write one such myself. This one is of the simplest kind, and can only write 00's. That said, it is still to be proven unsufficient for datarecovery purposes. However, if you have top secret sensitive information that you are worried about someone being able to recover from a found disk sometime in the future (whenever and if, super advanced datarecovery methods unknown today, have been disclosed). So I guess you're safe for now. Or maybe you just want to clean out the disk before a fresh install. Anyways the basic tool I made uses winapi's like CreateFile, WriteFile and SetFilePointerEx, and is nothing fancy. But it is worth describing just how it works. And source is provided for those wanting to customize it further for their own need. 

Description:
Based on what Windows version version the WinPE is based on, any mounted volumes will be dismounted before proceeding. And only volumes from fixed disks will be dismounted, with exception for wherever systemroot and the tool itself is located. Next the tool will attempt overwriting \\.\PhysicalDrive0 and up to 30. That means it will auto-erase all connected \\.\PhysicalDriveN. This tool was made for use in nt6.x based WinPE, and therefore if run from nt5.x unexpected behaviour may occur. Furthermore, protection is in place, to prevent any harmful actions from an accidental execution on a regular live system. I therefore added a special boot configuration, where you need to add the LoadOptions string "DiskEraser". To set this entry in your BCD store run this command;

"bcdedit /store path\to\BCD /set {GUID} loadoptions DISKERASER"


When WinPE is booted with that boot configuration, it will be written into the registry, and that's where the tool identifies a correct environment for execution.

Now to configure this all to boot up and auto-erase the HDD completely automatic wihtout the need for any interaction, we need to make the tool launch when booting is finished. Several ways exist, but the one I chose, was with startnet.cmd. Since that script is autoexecuted when present (unless overrided by winpeshl.ini), we just put the name of the tool into startnet.cmd so it looks like this;

MyDiskEraser.exe


Put the tool into the systemroot (inside boot.wim), or you have to specify the path to it inside startnet.cmd.

So what about performance?
Have not really compared it, except a few tests with DBan, for which it performed kind of equal. The actual disk writing was roughly the same, but the boot time of DBan was horribly slow, which slowed its process down considerably.

I take no responsibility for what you do with this tool, and you are expected to know what you're doing before using this.
