/*
 *  Copyright (C) 1999 AT&T Laboratories Cambridge.  All Rights Reserved.
 *
 *  This is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  This software is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307,
 *  USA.
 */

/*
 * vncauth.c - Functions for VNC password management and authentication.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <unistd.h>
#include <vncauth.h>
#include <d3des.h>


/*
 * Make sure we call srandom() only once.
 */

static int s_srandom_called = 0;

/*
 * We use a fixed key to store passwords, since we assume that our local
 * file system is secure but nonetheless don't want to store passwords
 * as plaintext.
 */

static unsigned char s_fixedkey[8] = {23,82,107,6,35,78,88,7};


/*
 * Encrypt a password and store it in a file.  Returns 0 if successful,
 * 1 if the file could not be written.
 */

int
vncEncryptAndStorePasswd(char *passwd, char *fname)
{
    FILE *fp;
    int i;
    unsigned char encryptedPasswd[8];

    if ((fp = fopen(fname,"w")) == NULL) return 1;

    chmod(fname, S_IRUSR|S_IWUSR);

    /* pad password with nulls */

    for (i = 0; i < 8; i++) {
	if (i < strlen(passwd)) {
	    encryptedPasswd[i] = passwd[i];
	} else {
	    encryptedPasswd[i] = 0;
	}
    }

    /* Do encryption in-place - this way we overwrite our copy of the plaintext
       password */

    deskey(s_fixedkey, EN0);
    des(encryptedPasswd, encryptedPasswd);

    for (i = 0; i < 8; i++) {
	putc(encryptedPasswd[i], fp);
    }
  
    fclose(fp);
    return 0;
}


/*
 * Decrypt a password from a file.  Returns a pointer to a newly allocated
 * string containing the password or a null pointer if the password could
 * not be retrieved for some reason.
 */

char *
vncDecryptPasswdFromFile(char *fname)
{
    FILE *fp;
    int i, ch;
    unsigned char *passwd = (unsigned char *)malloc(9);

    if (strcmp(fname, "-") != 0) {
	if ((fp = fopen(fname,"r")) == NULL)
	    return NULL;
    } else {
	fp = stdin;
    }

    for (i = 0; i < 8; i++) {
	ch = getc(fp);
	if (ch == EOF)
	    break;
	passwd[i] = ch;
    }

    if (fp != stdin)
	fclose(fp);

    if (i != 8)                 /* Could not read eight bytes */
	return NULL;

    deskey(s_fixedkey, DE1);
    des(passwd, passwd);

    passwd[8] = 0;

    return (char *)passwd;
}


/*
 * Generate CHALLENGESIZE random bytes for use in challenge-response
 * authentication.
 */

void
vncRandomBytes(unsigned char *bytes)
{
    int i;
    unsigned int seed;

    if (!s_srandom_called) {
      seed = (unsigned int)time(0) ^ (unsigned int)getpid();
      srandom(seed);
      s_srandom_called = 1;
    }

    for (i = 0; i < CHALLENGESIZE; i++) {
	bytes[i] = (unsigned char)(random() & 255);    
    }
}


/*
 * Encrypt CHALLENGESIZE bytes in memory using a password.
 */

void
vncEncryptBytes(unsigned char *bytes, char *passwd)
{
    unsigned char key[8];
    int i;

    /* key is simply password padded with nulls */

    for (i = 0; i < 8; i++) {
	if (i < strlen(passwd)) {
	    key[i] = passwd[i];
	} else {
	    key[i] = 0;
	}
    }

    deskey(key, EN0);

    for (i = 0; i < CHALLENGESIZE; i += 8) {
	des(bytes+i, bytes+i);
    }
}
