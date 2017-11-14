#include <FileUtils.hh>
#include <util/strings.h>
#include <fs/sys.hh>
#include <base/Base.hh>
#include <spawn.h>

void chdirFromFilePath(const char *path)
{
	FsSys::cPath dirnameTemp;
	FsSys::chdir(string_dirname(path, dirnameTemp));
}

extern char **environ;
void fixFilePermissions(const char *path)
{
	if(FsSys::hasWriteAccess(path) == 0)
	{
		logMsg("%s lacks write permission, setting user as owner", path);
	}
	else
		return;

	FsSys::cPath execPath;
	string_printf(execPath, "%s/fixMobilePermission '%s'", Base::appPath, path);
	//logMsg("executing %s", execPath);
    pid_t pid;
    char *argv[] = {
        execPath,
        NULL
    };
    
    int err = posix_spawn(&pid, argv[0], NULL, NULL, argv, environ);
    waitpid(pid, NULL, 0);
	if(err)
	{
		logWarn("error from fixMobilePermission helper: %d", err);
	}
}
