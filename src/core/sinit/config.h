/* See LICENSE file for copyright and license details. */

static char *const rcinitcmd[]     = { "/etc/rc.d/rc.init", NULL };
static char *const rcrebootcmd[]   = { "/etc/rc.d/rc.shutdown", "reboot", NULL };
static char *const rcpoweroffcmd[] = { "/etc/rc.d/rc.shutdown", "poweroff", NULL };