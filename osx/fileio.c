//============================================================
//
//  fileio.c - SDL/POSIX file access functions
//
//  Copyright (c) 1996-2006, Nicola Salmoria and the MAME Team.
//  Visit http://mamedev.org for licensing and usage restrictions.
//
//  SDLMAME by Olivier Galibert and R. Belmont
//
//============================================================

#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>
#include <ctype.h>
#include <errno.h>

// MAME headers
#include "osdepend.h"
#include "driver.h"
#include "unzip.h"
#include "options.h"

#ifdef MESS
#include "image.h"
#endif


#define VERBOSE				0

#define MAX_OPEN_FILES		128
#define FILE_BUFFER_SIZE	256


//============================================================
//	EXTERNALS
//============================================================

extern char *rompath_extra;

// from cheat.c
extern char *cheatfile;



//============================================================
//	TYPE DEFINITIONS
//============================================================

struct pathdata
{
	const char *rawpath;
	const char **path;
	int pathcount;
};

struct _osd_file
{
	int 		handle;
	UINT64		filepos;
	UINT64		end;
	UINT64		offset;
	UINT64		bufferbase;
	long		bufferbytes;
	UINT8		buffer[FILE_BUFFER_SIZE];
};

static struct pathdata pathlist[FILETYPE_end];
static osd_file openfile[MAX_OPEN_FILES];



//============================================================
//	GLOBAL VARIABLES
//============================================================

static const struct
{
	int	filetype;
	const char *option;
} fileio_options[] =
{
#ifndef MESS
	{ FILETYPE_ROM,			"rompath" },
	{ FILETYPE_IMAGE,		"rompath" },
#else
	{ FILETYPE_ROM,			"biospath" },
	{ FILETYPE_IMAGE,		"softwarepath" },
	{ FILETYPE_HASH,		"hash_directory" },
#endif
	{ FILETYPE_IMAGE_DIFF,	"diff_directory" },
	{ FILETYPE_SAMPLE,		"samplepath" },
	{ FILETYPE_ARTWORK,		"artpath" },
	{ FILETYPE_NVRAM,		"nvram_directory" },
	{ FILETYPE_HIGHSCORE,	"hiscore_directory" },
	{ FILETYPE_CONFIG,		"cfg_directory" },
	{ FILETYPE_INPUTLOG,	"input_directory" },
	{ FILETYPE_STATE,		"state_directory" },
	{ FILETYPE_MEMCARD,		"memcard_directory" },
	{ FILETYPE_SCREENSHOT,	"snapshot_directory" },
	{ FILETYPE_MOVIE,		"snapshot_directory" },
	{ FILETYPE_CTRLR,		"ctrlrparth" },
	{ FILETYPE_INI,			"inipath" },
	{ FILETYPE_COMMENT,		"comment_directory" },
	{ 0 }
};

//============================================================
//	is_pathsep
//============================================================

INLINE int is_pathsep(char c)
{
	return (c == '/' || c == '\\' || c == ':');
}



//============================================================
//	find_reverse_path_sep
//============================================================

static char *find_reverse_path_sep(char *name)
{
	char *p = name + strlen(name) - 1;
	while (p >= name && !is_pathsep(*p))
		p--;
	return (p >= name) ? p : NULL;
}



//============================================================
//	create_path
//============================================================

static int create_path(char *path, int has_filename)
{
	char *sep = find_reverse_path_sep(path);
	struct stat st;

	/* if there's still a separator, and it's not the root, nuke it and recurse */
	if (sep && sep > path && !is_pathsep(sep[-1]))
	{
		*sep = 0;
		if (!create_path(path, 0))
			return 0;
		#ifdef SDLMAME_WIN32
		*sep = '\\';
		#else
		*sep = '/';
		#endif
	}
	
	/* if we have a filename, we're done */
	if (has_filename)
		return 1;
	
	/* if the path already exists, we're done */
	if (!stat(path, &st))
		return 0;
	
	/* create the path */
	#ifdef SDLMAME_WIN32
	return !mkdir(path);
	#else
	return !mkdir(path, 0777);
	#endif
}



//============================================================
//	is_variablechar
//============================================================

INLINE int is_variablechar(char c)
{
	return (isalnum(c) || c == '_' || c == '-');
}



//============================================================
//	parse_variable
//============================================================

static const char *parse_variable(const char **start, const char *end)
{
	const char *src = *start, *var;
	char variable[1024];
	char *dest = variable;
	
	/* copy until we hit the end or until we hit a non-variable character */
	for (src = *start; src < end && is_variablechar(*src); src++)
		*dest++ = *src;
	
	/* NULL terminate and return a pointer to the end */
	*dest = 0;
	*start = src;

	/* return the actuval variable value */
	var = getenv(variable);
	return (var) ? var : "";
}



//============================================================
//	copy_and_expand_variables
//============================================================

static char *copy_and_expand_variables(const char *path, int len)
{
	char *dst, *result;
	const char *src;
	int length = 0;

	/* first determine the length of the expanded string */
	for (src = path; src < path + len; )
		if (*src++ == '$')
			length += strlen(parse_variable(&src, path + len));
		else
			length++;

	/* allocate a string of the appropriate length */
	result = malloc(length + 1);
	if (!result)
		goto out_of_memory;

	/* now actually generate the string */
	for (src = path, dst = result; src < path + len; )
	{
		char c = *src++;
		if (c == '$')
			dst += sprintf(dst, "%s", parse_variable(&src, path + len));
		else
			*dst++ = c;
	}
	
	/* NULL terminate and return */
	*dst = 0;
	return result;

out_of_memory:
	fprintf(stderr, "Out of memory in variable expansion!\n");
	exit(1);
}

//============================================================
//  free_pathlist
//============================================================

void free_pathlist(struct pathdata *list)
{
	// free any existing paths
	if (list->pathcount != 0)
	{
		int pathindex;

		for (pathindex = 0; pathindex < list->pathcount; pathindex++)
			free((void *)list->path[pathindex]);
		free((void *)list->path);
	}

	// by default, start with an empty list
	list->path = NULL;
	list->pathcount = 0;
}

//============================================================
//  expand_pathlist
//============================================================

static void expand_pathlist(struct pathdata *list, const char *rawpath)
{
	const char *token;

#if VERBOSE
	printf("Expanding: %s\n", rawpath);
#endif

	// free any existing paths
	free_pathlist(list);

	// look for separators
	token = strchr(rawpath, ';');
	if (!token)
		token = rawpath + strlen(rawpath);

	// loop until done
	while (1)
	{
		// allocate space for the new pointer
		list->path = realloc((void *)list->path, (list->pathcount + 1) * sizeof(char *));
		assert_always(list->path != NULL, "Out of memory!");

		// copy the path in
		list->path[list->pathcount++] = copy_and_expand_variables(rawpath, token - rawpath);
#if VERBOSE
		printf("  %s\n", list->path[list->pathcount - 1]);
#endif

		// if this was the end, break
		if (*token == 0)
			break;
		rawpath = token + 1;

		// find the next separator
		token = strchr(rawpath, ';');
		if (!token)
			token = rawpath + strlen(rawpath);
	}
}


//============================================================
//  free_pathlists
//============================================================

void free_pathlists(void)
{
	int i;

	for (i = 0;i < FILETYPE_end;i++)
		free_pathlist(&pathlist[i]);
}

//============================================================
//	get_path_for_filetype
//============================================================

static const char *get_path_for_filetype(int filetype, int pathindex, UINT32 *count)
{
	struct pathdata *list = &pathlist[filetype];

	// if we don't have expanded paths, expand them now
	if (list->pathcount == 0)
	{
		const char *rawpath = NULL;
		int optnum;

		// find the filetype in the list of options
		for (optnum = 0; fileio_options[optnum].option != NULL; optnum++)
			if (fileio_options[optnum].filetype == filetype)
			{
				rawpath = options_get_string(fileio_options[optnum].option, FALSE);
				break;
			}

		// if we don't have a path, set an empty string
		if (rawpath == NULL)
			rawpath = "";

		// decompose the path
		expand_pathlist(list, rawpath);
	}

	// set the count
	if (count)
		*count = list->pathcount;

	// return a valid path always
	return (pathindex < list->pathcount) ? list->path[pathindex] : "";
}



//============================================================
//	compose_path
//============================================================

static void compose_path(char *output, int pathtype, int pathindex, const char *filename)
{
	const char *basepath = get_path_for_filetype(pathtype, pathindex, NULL);
	#ifndef SDLMAME_WIN32
	char *p;
	#endif

#ifdef MESS
	if (osd_is_absolute_path(filename))
		basepath = NULL;
#endif

	/* compose the full path */
	*output = 0;
	if (basepath)
		strcat(output, basepath);
	if (*output && !is_pathsep(output[strlen(output) - 1]))
		#ifndef SDLMAME_WIN32
		strcat(output, "/");
		#else
		strcat(output, "\\");
		#endif
	strcat(output, filename);

	/* convert forward slashes to backslashes */
	#ifndef SDLMAME_WIN32
	for (p = output; *p; p++)
		if (*p == '\\')
			*p = '/';
	#endif
}



//============================================================
//	osd_get_path_count
//============================================================

int osd_get_path_count(int pathtype)
{
	UINT32 count;
	
	/* get the count and return it */
	get_path_for_filetype(pathtype, 0, &count);
	return count;
}



//============================================================
//	osd_get_path_info
//============================================================

int osd_get_path_info(int pathtype, int pathindex, const char *filename)
{
	char fullpath[1024];
	long attributes;
	struct stat stats;

	/* compose the full path */
	compose_path(fullpath, pathtype, pathindex, filename);

	/* get the file attributes */
	attributes = stat(fullpath, &stats);
	if (attributes != 0)
		return PATH_NOT_FOUND;
	else if (S_ISDIR(stats.st_mode))
		return PATH_IS_DIRECTORY;
	else
		return PATH_IS_FILE;
}



//============================================================
//	osd_fopen
//============================================================

osd_file *osd_fopen(int pathtype, int pathindex, const char *filename, const char *mode, osd_file_error *error)
{
	long access = 0;
	char fullpath[1024];
	osd_file *file;
	int i;
	struct stat stats;

	*error = 0;

	/* find an empty file handle */
	for (i = 0; i < MAX_OPEN_FILES; i++)
		if (openfile[i].handle == 0)
			break;
	if (i == MAX_OPEN_FILES)
	{
		*error = FILEERR_TOO_MANY_FILES;
		return 0;
	}

	/* zap the file record */
	file = &openfile[i];
	memset(file, 0, sizeof(*file));
	
	/* convert the mode into disposition and access */
	if (strchr(mode, 'r'))
		access = O_RDONLY;
	if (strchr(mode, 'w'))
		access = O_CREAT | O_WRONLY | O_TRUNC;
	if (strchr(mode, '+'))
		access = O_RDWR | O_CREAT ;
	#ifdef SDLMAME_WIN32
	if (strchr(mode, 'b'))
		access |= O_BINARY;
	else
		access |= O_TEXT;
	#endif
	
	/* compose the full path */
	compose_path(fullpath, pathtype, pathindex, filename);

#if 0
	if (strchr(mode, 'w'))
		printf("Opening [%s] for write\n", fullpath);
	else
		printf("Opening [%s] for read\n", fullpath);

	if (strchr(mode, '+'))
		printf("Create OK\n");
#endif

	/* attempt to open the file */
	file->handle = open(fullpath, access, S_IRWXU);
	if (file->handle == -1)
	{
		/* if no create access, then that's final */
		if (!(access & O_CREAT))
		{
			file->handle = 0;
			return NULL;
		}
	
		/* create the path and try again */
		create_path(fullpath, 1);

		file->handle = creat(fullpath, S_IRWXU);
	
		/* if that doesn't work, we give up */
		if (file->handle == -1)
		{
			file->handle = 0;
			return NULL;
		}
	}

	/* get the file size */
	fstat(file->handle, &stats);
	file->end = stats.st_size;

	return file;
}



//============================================================
//	osd_fseek
//============================================================

int osd_fseek(osd_file *file, INT64 offset, int whence)
{
	/* convert the whence into method */
	switch (whence)
	{
		default:
		case SEEK_SET:	file->offset = offset;				break;
		case SEEK_CUR:	file->offset += offset;				break;
		case SEEK_END:	file->offset = file->end + offset;	break;
	}
	return 0;
}



//============================================================
//	osd_ftell
//============================================================

UINT64 osd_ftell(osd_file *file)
{
	return file->offset;
}



//============================================================
//	osd_feof
//============================================================

int osd_feof(osd_file *file)
{
	return (file->offset >= file->end);
}



//============================================================
//	osd_fread
//============================================================

UINT32 osd_fread(osd_file *file, void *buffer, UINT32 length)
{
	UINT32 bytes_left = length;
	int bytes_to_copy;
	long result;

	// handle data from within the buffer
	if (file->offset >= file->bufferbase && file->offset < file->bufferbase + file->bufferbytes)
	{
		// copy as much as we can
		bytes_to_copy = file->bufferbase + file->bufferbytes - file->offset;
		if (bytes_to_copy > length)
			bytes_to_copy = length;
		memcpy(buffer, &file->buffer[file->offset - file->bufferbase], bytes_to_copy);
		
		// account for it
		bytes_left -= bytes_to_copy;
		file->offset += bytes_to_copy;
		buffer = (UINT8 *)buffer + bytes_to_copy;

		// if that's it, we're done
		if (bytes_left == 0)
			return length;
	}

	// attempt to seek to the current location if we're not there already
	if (file->offset != file->filepos)
	{
//		long upperPos = file->offset >> 32;
		result = lseek(file->handle, (UINT32)file->offset, SEEK_SET);
		if (result == -1)
		{
			file->filepos = ~0;
			return length - bytes_left;
		}
		file->filepos = file->offset;
	}
	
	// if we have a small read remaining, do it to the buffer and copy out the results
	if (length < FILE_BUFFER_SIZE/2)
	{
		// read as much of the buffer as we can
		file->bufferbase = file->offset;
		file->bufferbytes = 0;
		file->bufferbytes = read(file->handle, file->buffer, FILE_BUFFER_SIZE);
		file->filepos += file->bufferbytes;
		
		// copy it out
		bytes_to_copy = bytes_left;
		if (bytes_to_copy > file->bufferbytes)
			bytes_to_copy = file->bufferbytes;
		memcpy(buffer, file->buffer, bytes_to_copy);
		
		// adjust pointers and return
		file->offset += bytes_to_copy;
		bytes_left -= bytes_to_copy;
		return length - bytes_left;
	}
	
	// otherwise, just read directly to the buffer
	else
	{
		// do the read
		result = read(file->handle, buffer, bytes_left);
		
		file->filepos += result;

		// adjust the pointers and return
		file->offset += result;
		bytes_left -= result;
		return length - bytes_left;
	}
}



//============================================================
//	osd_fwrite
//============================================================

UINT32 osd_fwrite(osd_file *file, const void *buffer, UINT32 length)
{
	long upperPos;
	long result;
	
	// invalidate any buffered data
	file->bufferbytes = 0;

	// attempt to seek to the current location
	upperPos = file->offset >> 32;
	result = lseek(file->handle, (UINT32)file->offset, SEEK_SET);
	if (result == -1)
		return 0;
	
	// do the write
	result = write(file->handle, buffer, length);

	file->filepos += result;
	
	// adjust the pointers
	file->offset += result;
	if (file->offset > file->end)
		file->end = file->offset;
	return result;
}



//============================================================
//	osd_fclose
//============================================================

void osd_fclose(osd_file *file)
{
//	printf("osd_fclose: %x\n", (unsigned int)file);
	// close the handle and clear it out
	if (file->handle)
		close(file->handle);

	file->handle = 0;
}



//============================================================
//  osd_create_directory
//============================================================

int osd_create_directory(int pathtype, int pathindex, const char *dirname)
{
	char fullpath[1024];

	/* compose the full path */
	compose_path(fullpath, pathtype, pathindex, dirname);
	return create_path(fullpath, FALSE);
}


#ifndef WINUI

//============================================================
//	osd_display_loading_rom_message
//============================================================

// called while loading ROMs. It is called a last time with name == 0 to signal
// that the ROM loading process is finished.
// return non-zero to abort loading
int osd_display_loading_rom_message(const char *name, rom_load_data *romdata)
{
	if (name)
		fprintf(stdout, "loading %-12s\r", name);
	else
		fprintf(stdout, "                    \r");
	fflush(stdout);

	return 0;
}

#endif

//============================================================
//  set_pathlist
//============================================================

void set_pathlist(int file_type, const char *new_rawpath)
{
	struct pathdata *list = &pathlist[file_type];

	// free any existing paths
	free_pathlist(list);

	// set a new path value if present
	if (new_rawpath)
		expand_pathlist(list, new_rawpath);
}

