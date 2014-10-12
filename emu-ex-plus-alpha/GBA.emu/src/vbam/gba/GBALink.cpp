// This file was written by denopqrihg
// with major changes by tjm
#include <string.h>
#include <stdio.h>

// malloc.h does not seem to exist on Mac OS 10.7
#ifdef __APPLE__
#include <stdlib.h>
#else
#include <malloc.h>
#endif

#ifdef _MSC_VER
#define snprintf _snprintf
#endif

static int vbaid = 0;
const char *MakeInstanceFilename(const char *Input)
{
	if (vbaid == 0)
		return Input;
    
	static char *result=NULL;
	if (result!=NULL)
		free(result);
    
	result = (char *)malloc(strlen(Input)+3);
	char *p = strrchr((char *)Input, '.');
	sprintf(result, "%.*s-%d.%s", (int)(p-Input), Input, vbaid+1, p+1);
	return result;
}

#ifndef NO_LINK

#define LOCAL_LINK_NAME "VBA link memory"
#define IP_LINK_PORT 5738

#include "../common/Port.h"
#include "GBA.h"
#include "GBALink.h"
#include "GBASockClient.h"

#include <SFML/Network.hpp>

#ifdef ENABLE_NLS
#include <libintl.h>
#define _(x) gettext(x)
#else
#define _(x) x
#endif

// #define N_(x) x Riley Testut



#if (defined __WIN32__ || defined _WIN32)
#include <windows.h>
#else
#include <sys/mman.h>
#include <time.h>
#include <semaphore.h>
#include <fcntl.h>
#include <errno.h>

#include <list>

#define ReleaseSemaphore(sem, nrel, orel) do { \
for(int i = 0; i < nrel; i++) \
sem_post(sem); \
} while(0)
#define WAIT_TIMEOUT -1
#ifdef HAVE_SEM_TIMEDWAIT
int WaitForSingleObject(sem_t *s, int t)
{
	struct timespec ts;
	clock_gettime(CLOCK_REALTIME, &ts);
	ts.tv_sec += t/1000;
	ts.tv_nsec += (t%1000) * 1000000;
	do {
		if(!sem_timedwait(s, &ts))
			return 0;
	} while(errno == EINTR);
	return WAIT_TIMEOUT;
}

// urg.. MacOSX has no sem_timedwait (POSIX) or semtimedop (SYSV)
// so we'll have to simulate it..
// MacOSX also has no clock_gettime, and since both are "real-time", assume
// anyone who doesn't have one also doesn't have the other

// 2 ways to do this:
//   - poll & sleep loop
//   - poll & wait for timer interrupt loop

// the first consumes more CPU and requires selection of a good sleep value

// the second may interfere with other timers running on system, and
// requires that a dummy signal handler be installed for SIGALRM
#else
#include <sys/time.h>
#ifndef TIMEDWAIT_ALRM
#define TIMEDWAIT_ALRM 1
#endif
#if TIMEDWAIT_ALRM
#include <signal.h>
static void alrmhand(int sig)
{
}
#endif
int WaitForSingleObject(sem_t *s, int t)
{
#if !TIMEDWAIT_ALRM
	struct timeval ts;
	gettimeofday(&ts, NULL);
	ts.tv_sec += t/1000;
	ts.tv_usec += (t%1000) * 1000;
#else
	struct sigaction sa, osa;
	sigaction(SIGALRM, NULL, &osa);
	sa = osa;
	sa.sa_flags &= ~SA_RESTART;
	sa.sa_handler = alrmhand;
	sigaction(SIGALRM, &sa, NULL);
	struct itimerval tv, otv;
	tv.it_value.tv_sec = t / 1000;
	tv.it_value.tv_usec = (t%1000) * 1000;
	// this should be 0/0, but in the wait loop, it's possible to
	// have the signal fire while not in sem_wait().  This will ensure
	// another signal within 1ms
	tv.it_interval.tv_sec = 0;
	tv.it_interval.tv_usec = 999;
	setitimer(ITIMER_REAL, &tv, &otv);
#endif
	while(1) {
#if !TIMEDWAIT_ALRM
		if(!sem_trywait(s))
			return 0;
		struct timeval ts2;
		gettimeofday(&ts2, NULL);
		if(ts2.tv_sec > ts.tv_sec || (ts2.tv_sec == ts.tv_sec &&
                                      ts2.tv_usec > ts.tv_usec)) {
			return WAIT_TIMEOUT;
		}
		// is .1 ms short enough?  long enough?  who knows?
		struct timespec ts3;
		ts3.tv_sec = 0;
		ts3.tv_nsec = 100000;
		nanosleep(&ts3, NULL);
#else
		if(!sem_wait(s)) {
			setitimer(ITIMER_REAL, &otv, NULL);
			sigaction(SIGALRM, &osa, NULL);
			return 0;
		}
		getitimer(ITIMER_REAL, &tv);
		if(tv.it_value.tv_sec || tv.it_value.tv_usec > 999)
			continue;
		setitimer(ITIMER_REAL, &otv, NULL);
		sigaction(SIGALRM, &osa, NULL);
		break;
#endif
	}
	return WAIT_TIMEOUT;
}
#endif
#endif

#define UNSUPPORTED -1
#define MULTIPLAYER 0
#define NORMAL8 1
#define NORMAL32 2
#define UART 3
#define JOYBUS 4
#define GP 5

#define RFU_INIT 0
#define RFU_COMM 1
#define RFU_SEND 2
#define RFU_RECV 3

#define RF_RECVCMD			0x278 //AdamN: Unknown, Seems to be related to Wireless Adpater(RF_RCNT or armMode/CPSR or CMD sent by the adapter when RF_SIOCNT=0x83 or when RCNT=0x80aX?)
#define RF_CNT				0x27a //AdamN: Unknown, Seems to be related to Wireless Adpater(RF_SIOCNT?)

static ConnectionState InitIPC();
static ConnectionState InitSocket();
static ConnectionState JoyBusConnect();

static void JoyBusShutdown();
static void CloseIPC();
static void CloseSocket();
static void CloseRFUSocket();

static void StartCableSocket(u16 siocnt);
static void StartRFUIPC(u16 siocnt);
static void StartRFUSocket(u16 siocnt);
static void StartCableIPC(u16 siocnt);

static void JoyBusUpdate(int ticks);
static void UpdateCableIPC(int ticks);
static void UpdateRFUIPC(int ticks);
static void UpdateCableSocket(int ticks);
static void UpdateRFUSocket(int ticks);

bool LinkSendData(char *buf, int size, int nretry, int idx);
bool IsLinkConnected();

bool AppTerminated = false;
int RetryCount = 0;
bool gba_link_auto = true;
bool gba_link_enabled = false;
bool LinkFirstTime = true;

extern int GetTickCount();

void SetEvent(sem_t *)
{
    
}

void ResetEvent(sem_t *)
{
    
}

class GBALock {
    
public:
    
    void Lock()
    {
        
    }
    void Unlock()
    {
        
    }
    
};

GBALock c_s;

int minimum(int A, int B)
{
    if (A > B)
    {
        return A;
    }
    
    return B;
}

extern int GBALinkSendDataToPlayerAtIndex(int index, const char *data, size_t size);
extern int GBALinkReceiveDataFromPlayerAtIndex(int index, char *data, size_t maxSize);
extern bool GBALinkWaitForLinkDataWithTimeout(int timeout);

static ConnectionState ConnectUpdateSocket(char * const message, size_t size);

struct LinkDriver {
	typedef ConnectionState (ConnectFunc)();
	typedef ConnectionState (ConnectUpdateFunc)(char * const message, size_t size);
	typedef void (StartFunc)(u16 siocnt);
	typedef void (UpdateFunc)(int ticks);
	typedef void (CloseFunc)();
    
	LinkMode mode;
	ConnectFunc *connect;
	ConnectUpdateFunc *connectUpdate;
	StartFunc *start;
	UpdateFunc *update;
	CloseFunc *close;
};
static const LinkDriver linkDrivers[] =
{
	{ LINK_CABLE_IPC,			InitIPC,		NULL,					StartCableIPC,		UpdateCableIPC,     CloseIPC },
	{ LINK_CABLE_SOCKET,		InitSocket,		ConnectUpdateSocket,	StartCableSocket,	UpdateCableSocket,  CloseSocket },
	{ LINK_RFU_IPC,				InitIPC,		NULL,					StartRFUIPC,        UpdateRFUIPC,       CloseIPC },
    { LINK_RFU_SOCKET,          InitSocket,     ConnectUpdateSocket,    StartRFUSocket,     UpdateRFUSocket,    CloseRFUSocket },
	{ LINK_GAMECUBE_DOLPHIN,	JoyBusConnect,	NULL,					NULL,				JoyBusUpdate,       JoyBusShutdown }
};


enum
{
	JOY_CMD_RESET	= 0xff,
	JOY_CMD_STATUS	= 0x00,
	JOY_CMD_READ	= 0x14,
	JOY_CMD_WRITE	= 0x15
};

#define UPDATE_REG(address, value) WRITE16LE(((u16 *)&gGba.mem.ioMem.b[address]),value)

typedef struct {
	u16 linkdata[5];
	u16 linkcmd;
	u16 numtransfers;
	int lastlinktime;
	u8 numgbas;
	u8 trgbas;
	u8 linkflags;
    u16 rfu_qid[5];
	int rfu_q[4];
	int rfu_linktime[4];
	u32 rfu_bdata[4][7];
	u32 rfu_data[4][32];
    u32 rfu_signal[5];
    
    u8 rfu_recvcmd[5]; //last received command
    u8 rfu_proto[5]; // 0=UDP-like, 1=TCP-like protocols to see whether the data important or not (may or may not be received successfully by the other side)
    u8 rfu_request[5]; //request to join
    //u8 rfu_joined[5]; //bool //currenlty joined
    u16 rfu_reqid[5]; //id to join
    u16 rfu_clientidx[5]; //only used by clients
    s32 rfu_latency[5];
    u32 rfu_gdata[5]; //for 0x17/0x19?/0x1e?
    s32 rfu_state[5]; //0=none, 1=waiting for ACK
    u8  rfu_listfront[5];
    u8  rfu_listback[5];
} LINKDATA;

typedef struct {
	sf::SocketTCP tcpsocket;
	int numslaves;
	int connectedSlaves;
	int type;
	bool server;
	bool speed;
} LANLINKDATA;

class lserver{
	int numbytes;
	sf::Selector<sf::SocketTCP> fdset;
	//timeval udptimeout;
	char inbuffer[256], outbuffer[256];
	s32 *intinbuffer;
	u16 *u16inbuffer;
	s32 *intoutbuffer;
	u16 *u16outbuffer;
	int counter;
	int done;
public:
	int howmanytimes;
	sf::SocketTCP tcpsocket[4];
	sf::IPAddress udpaddr[4];
	lserver(void);
	void Send(void);
	void Recv(void);
    
    int initd = 0;
};

class lclient{
	sf::Selector<sf::SocketTCP> fdset;
	char inbuffer[256], outbuffer[256];
	s32 *intinbuffer;
	u16 *u16inbuffer;
	s32 *intoutbuffer;
	u16 *u16outbuffer;
	int numbytes;
public:
	sf::IPAddress serveraddr;
	unsigned short serverport;
	int numtransfers;
	lclient(void);
	void Send(void);
	void Recv(void);
	void CheckConn(void);
};

static const LinkDriver *linkDriver = NULL;
static ConnectionState gba_connection_state = LINK_OK;

LinkMode GetLinkMode() {
	if (linkDriver && gba_connection_state == LINK_OK)
		return linkDriver->mode;
	else
		return LINK_DISCONNECTED;
}

static int linktime = 0;

static GBASockClient* dol = NULL;
static sf::IPAddress joybusHostAddr = sf::IPAddress::LocalHost;

typedef struct {
    u8 len; //data len in 32bit words
    u8 idx; //client idx
    u8 gbaid; //source id
    u8 qid; //target ids
    u32 sign; //signal
    u32 time; //linktime
    u32 data[255];
} rfu_datarec;

std::list<rfu_datarec> DATALIST;
std::list<rfu_datarec>::iterator DATALIST_I;
rfu_datarec tmpDataRec;

// Hodgepodge
static u8 tspeed = 3;
static u8 transfer = 0;
static LINKDATA linkmem;
static int linkid = 0;
#if (defined __WIN32__ || defined _WIN32)
static HANDLE linksync[4];
#else
static sem_t *linksync[4];
#endif
static int savedlinktime = 0;
#if (defined __WIN32__ || defined _WIN32)
static HANDLE mmf = NULL;
#else
static int mmf = -1;
#endif
static char linkevent[] =
#if !(defined __WIN32__ || defined _WIN32)
"/"
#endif
"VBA link event  ";
static int i, j;
static int linktimeout = 1000;
static LANLINKDATA lanlink;
static u16 linkdata[4];
static lserver ls;
static lclient lc;
static bool oncewait = false, after = false;

// RFU crap (except for numtransfers note...should probably check that out)
bool rfu_enabled = false;
bool rfu_initialized = false;
bool rfu_waiting = false;
bool rfu_wastimeout = false;
u8 rfu_cmd, rfu_qsend, rfu_qrecv, rfu_qsend2, rfu_cmd2, rfu_lastcmd, rfu_lastcmd2, rfu_lastcmd3;
u16 rfu_id, rfu_thisid, rfu_idx;
static int gbaid = 0;
static int roomid = 0;
static int gbaidx = 0;
bool rfu_ishost, rfu_isfirst, rfu_cansend;
int rfu_state, rfu_polarity, linktime2, rfu_counter, rfu_masterq; //, rfu_cacheq;
unsigned long rfu_lasttime;
u32 rfu_buf;
int rfu_lastq; //u8
u16 rfu_lastqid;
u16 PrevVAL = 0;
u32 PrevCOM = 0, PrevDAT = 0;
// numtransfers seems to be used interchangeably with linkmem.numtransfers
// probably a bug?
int rfu_transfer_end, numtransfers = 0;
u8 rfu_numclients = 0; //# of clients joined
u8 rfu_curclient = 0; //currently client
u32 rfu_clientlist[5]; //list of clients joined, sorted by the time they joined (index 0 = first one joined), high-16bit may also contains index
s32 rfu_clientstate[5]; //0=none, 1=waiting for ACK
u32 rfu_masterdata[255]; //[5*35];//, rfu_cachedata[35]; //for 0x24-0x26, temp buffer before data actually sent to other gbas or cache after read
u32 rfu_bufferdata[64][256]; //buffer for masterdata from sockets (64 queues of GBAID + 255 words of data)
int rfu_bufferidx = 0;

// time to end of single GBA's transfer, in 16.78 MHz clock ticks
// first index is GBA #
static const int trtimedata[4][4] = {
    // 9600 38400 57600 115200
	{34080, 8520, 5680, 2840},
	{65536, 16384, 10923, 5461},
	{99609, 24903, 16602, 8301},
	{133692, 33423, 22282, 11141}
};

// time to end of transfer
// for 3 slaves, this is time to transfer machine 4
// for < 3 slaves, this is time to transfer last machine + time to detect lack
// of start bit from next slave
// first index is (# of slaves) - 1
static const int trtimeend[3][4] = {
    // 9600 38400 57600 115200
	{72527, 18132, 12088, 6044},
	{106608, 26652, 17768, 8884},
	{133692, 33423, 22282, 11141}
};

static int GetSIOMode(u16, u16);

// The GBA wireless RFU (see adapter3.txt)
// Just try to avert your eyes for now ^^ (note, it currently can be called, tho)
static void StartRFUIPC(u16 siocnt)
{
	switch (GetSIOMode(siocnt, READ16LE(&gGba.mem.ioMem.b[COMM_RCNT]))) {
        case NORMAL8:
            rfu_polarity = 0;
            break;
            
        case NORMAL32:
            if (siocnt & 8)
                siocnt &= 0xfffb;	// A kind of acknowledge procedure
            else
                siocnt |= 4;
            
            if (siocnt & 0x80)
            {
                if ((siocnt&3) == 1)
                    rfu_transfer_end = 2048;
                else
                    rfu_transfer_end = 256;
                
                u16 a = READ16LE(&gGba.mem.ioMem.b[COMM_SIODATA32_H]);
                
                switch (rfu_state) {
                    case RFU_INIT:
                        if (READ32LE(&gGba.mem.ioMem.b[COMM_SIODATA32_L]) == 0xb0bb8001)
                            rfu_state = RFU_COMM;	// end of startup
                        
                        UPDATE_REG(COMM_SIODATA32_H, READ16LE(&gGba.mem.ioMem.b[COMM_SIODATA32_L]));
                        UPDATE_REG(COMM_SIODATA32_L, a);
                        break;
                        
                    case RFU_COMM:
                        if (a == 0x9966)
                        {
                            rfu_cmd = gGba.mem.ioMem.b[COMM_SIODATA32_L];
                            if ((rfu_qsend=gGba.mem.ioMem.b[0x121]) != 0) {
                                rfu_state = RFU_SEND;
                                rfu_counter = 0;
                            }
                            if (rfu_cmd == 0x25 || rfu_cmd == 0x24) {
                                linkmem.rfu_q[vbaid] = rfu_qsend;
                            }
                            UPDATE_REG(COMM_SIODATA32_L, 0);
                            UPDATE_REG(COMM_SIODATA32_H, 0x8000);
                        }
                        else if (a == 0x8000)
                        {
                            switch (rfu_cmd) {
                                case 0x1a:	// check if someone joined
                                    if (linkmem.rfu_request[vbaid] != 0) {
                                        rfu_state = RFU_RECV;
                                        rfu_qrecv = 1;
                                    }
                                    linkid = -1;
                                    rfu_cmd |= 0x80;
                                    break;
                                    
                                case 0x1e:	// receive broadcast data
                                case 0x1d:	// no visible difference
                                    rfu_polarity = 0;
                                    rfu_state = RFU_RECV;
                                    rfu_qrecv = 7;
                                    rfu_counter = 0;
                                    rfu_cmd |= 0x80;
                                    break;
                                    
                                case 0x30:
                                    linkmem.rfu_request[vbaid] = 0;
                                    linkmem.rfu_q[vbaid] = 0;
                                    linkid = 0;
                                    numtransfers = 0;
                                    rfu_cmd |= 0x80;
                                    if (linkmem.numgbas == 2)
                                        ReleaseSemaphore(linksync[1-vbaid], 1, NULL);
                                    break;
                                    
                                case 0x11:	// ? always receives 0xff - I suspect it's something for 3+ players
                                case 0x13:	// unknown
                                case 0x20:	// this has something to do with 0x1f
                                case 0x21:	// this too
                                    rfu_cmd |= 0x80;
                                    rfu_polarity = 0;
                                    rfu_state = 3;
                                    rfu_qrecv = 1;
                                    break;
                                    
                                case 0x26:
                                    if(linkid>0){
                                        rfu_qrecv = rfu_masterq;
                                    }
                                    if((rfu_qrecv=linkmem.rfu_q[1-vbaid])!=0){
                                        rfu_state = RFU_RECV;
                                        rfu_counter = 0;
                                    }
                                    rfu_cmd |= 0x80;
                                    break;
                                    
                                case 0x24:	// send data
                                    if((numtransfers++)==0) linktime = 1;
                                    linkmem.rfu_linktime[vbaid] = linktime;
                                    if(linkmem.numgbas==2){
                                        ReleaseSemaphore(linksync[1-vbaid], 1, NULL);
                                        WaitForSingleObject(linksync[vbaid], linktimeout);
                                    }
                                    rfu_cmd |= 0x80;
                                    linktime = 0;
                                    linkid = -1;
                                    break;
                                    
                                case 0x25:	// send & wait for data
                                case 0x1f:	// pick a server
                                case 0x10:	// init
                                case 0x16:	// send broadcast data
                                case 0x17:	// setup or something ?
                                case 0x27:	// wait for data ?
                                case 0x3d:	// init
                                default:
                                    rfu_cmd |= 0x80;
                                    break;
                                    
                                case 0xa5:	//	2nd part of send&wait function 0x25
                                case 0xa7:	//	2nd part of wait function 0x27
                                    if (linkid == -1) {
                                        linkid++;
                                        linkmem.rfu_linktime[vbaid] = 0;
                                    }
                                    if (linkid&&linkmem.rfu_request[1-vbaid] == 0) {
                                        linkmem.rfu_q[1-vbaid] = 0;
                                        rfu_transfer_end = 256;
                                        rfu_polarity = 1;
                                        rfu_cmd = 0x29;
                                        linktime = 0;
                                        break;
                                    }
                                    if ((numtransfers++) == 0)
                                        linktime = 0;
                                    linkmem.rfu_linktime[vbaid] = linktime;
                                    if (linkmem.numgbas == 2) {
                                        if (!linkid || (linkid && numtransfers))
                                            ReleaseSemaphore(linksync[1-vbaid], 1, NULL);
                                        WaitForSingleObject(linksync[vbaid], linktimeout);
                                    }
                                    if ( linkid > 0) {
                                        memcpy(rfu_masterdata, linkmem.rfu_data[1-vbaid], 128);
                                        rfu_masterq = linkmem.rfu_q[1-vbaid];
                                    }
                                    rfu_transfer_end = linkmem.rfu_linktime[1-vbaid] - linktime + 256;
                                    
                                    if (rfu_transfer_end < 256)
                                        rfu_transfer_end = 256;
                                    
                                    linktime = -rfu_transfer_end;
                                    rfu_polarity = 1;
                                    rfu_cmd = 0x28;
                                    break;
                            }
                            UPDATE_REG(COMM_SIODATA32_H, 0x9966);
                            UPDATE_REG(COMM_SIODATA32_L, (rfu_qrecv<<8) | rfu_cmd);
                            
                        } else {
                            
                            UPDATE_REG(COMM_SIODATA32_L, 0);
                            UPDATE_REG(COMM_SIODATA32_H, 0x8000);
                        }
                        break;
                        
                    case RFU_SEND:
                        if(--rfu_qsend == 0)
                            rfu_state = RFU_COMM;
                        
                        switch (rfu_cmd) {
                            case 0x16:
                                linkmem.rfu_bdata[vbaid][rfu_counter++] = READ32LE(&gGba.mem.ioMem.b[COMM_SIODATA32_L]);
                                break;
                                
                            case 0x17:
                                linkid = 1;
                                break;
                                
                            case 0x1f:
                                linkmem.rfu_request[1-vbaid] = 1;
                                break;
                                
                            case 0x24:
                            case 0x25:
                                linkmem.rfu_data[vbaid][rfu_counter++] = READ32LE(&gGba.mem.ioMem.b[COMM_SIODATA32_L]);
                                break;
                        }
                        UPDATE_REG(COMM_SIODATA32_L, 0);
                        UPDATE_REG(COMM_SIODATA32_H, 0x8000);
                        break;
                        
                    case RFU_RECV:
                        if (--rfu_qrecv == 0)
                            rfu_state = RFU_COMM;
                        
                        switch (rfu_cmd) {
                            case 0x9d:
                            case 0x9e:
                                if (rfu_counter == 0) {
                                    UPDATE_REG(COMM_SIODATA32_L, 0x61f1);
                                    UPDATE_REG(COMM_SIODATA32_H, 0);
                                    rfu_counter++;
                                    break;
                                }
                                UPDATE_REG(COMM_SIODATA32_L, linkmem.rfu_bdata[1-vbaid][rfu_counter-1]&0xffff);
                                UPDATE_REG(COMM_SIODATA32_H, linkmem.rfu_bdata[1-vbaid][rfu_counter-1]>>16);
                                rfu_counter++;
                                break;
                                
                            case 0xa6:
                                if (linkid>0) {
                                    UPDATE_REG(COMM_SIODATA32_L, rfu_masterdata[rfu_counter]&0xffff);
                                    UPDATE_REG(COMM_SIODATA32_H, rfu_masterdata[rfu_counter++]>>16);
                                } else {
                                    UPDATE_REG(COMM_SIODATA32_L, linkmem.rfu_data[1-vbaid][rfu_counter]&0xffff);
                                    UPDATE_REG(COMM_SIODATA32_H, linkmem.rfu_data[1-vbaid][rfu_counter++]>>16);
                                }
                                break;
                                
                            case 0x93:	// it seems like the game doesn't care about this value
                                UPDATE_REG(COMM_SIODATA32_L, 0x1234);	// put anything in here
                                UPDATE_REG(COMM_SIODATA32_H, 0x0200);	// also here, but it should be 0200
                                break;
                                
                            case 0xa0:
                            case 0xa1:
                                UPDATE_REG(COMM_SIODATA32_L, 0x641b);
                                UPDATE_REG(COMM_SIODATA32_H, 0x0000);
                                break;
                                
                            case 0x9a:
                                UPDATE_REG(COMM_SIODATA32_L, 0x61f9);
                                UPDATE_REG(COMM_SIODATA32_H, 0);
                                break;
                                
                            case 0x91:
                                UPDATE_REG(COMM_SIODATA32_L, 0x00ff);
                                UPDATE_REG(COMM_SIODATA32_H, 0x0000);
                                break;
                                
                            default:
                                UPDATE_REG(COMM_SIODATA32_L, 0x0173);
                                UPDATE_REG(COMM_SIODATA32_H, 0x0000);
                                break;
                        }
                        break;
                }
                transfer = 1;
            }
            
            if (rfu_polarity)
                siocnt ^= 4;	// sometimes it's the other way around
            break;
	}
    
	UPDATE_REG(COMM_SIOCNT, siocnt);
}

u16 PrepareRFUSocket(u16 value)
{
    
    printf("\nPrepareRFUSocket\n");
    
    //TODO: Need to use c_s.Lock/Unlock when accessing shared variable, or use LinkHandlerThread during idle instead of in a different thread
    static char inbuffer[1036], outbuffer[1036];
    u16 *u16inbuffer = (u16*)inbuffer;
    u16 *u16outbuffer = (u16*)outbuffer;
    u32 *u32inbuffer = (u32*)inbuffer;
    u32 *u32outbuffer = (u32*)outbuffer;
    static int outsize, insize;
    
    // GBARemove static char *st = "";
    //static CString st2 = _T(""); //since st.Format can't use it's self (st) as argument we need another CString
    
    static bool logstartd;
    //MSG msg;
    u32 CurCOM = 0, CurDAT = 0;
    bool rfulogd = (READ16LE(&gGba.mem.ioMem.b[COMM_SIOCNT])!=value);
    
    switch (GetSIOMode(value, READ16LE(&gGba.mem.ioMem.b[COMM_RCNT]))) {
        case NORMAL8: //occurs after sending 0x996600A8 cmd
            rfu_polarity = 0;
            //log("RFU Wait : %04X  %04X  %d\n", READ16LE(&gGba.mem.ioMem.b[COMM_RCNT]), READ16LE(&gGba.mem.ioMem.b[COMM_SIOCNT]), GetTickCount() );

            return value;
            break;
            
        case NORMAL32:
            if (transfer) {
                return value; //don't do anything if previous cmd aren't sent yet, may fix Boktai2 Not Detecting wireless adapter
            }
            
#ifdef GBA_LOGGING
            if(systemVerbose & VERBOSE_LINK) {
                if(!logstartd)
                    if(rfulogd) {
                        //log("%08X : %04X  ", GetTickCount(), value);
                        st.Format(_T("%08X : %04X[%04X]"), GetTickCount(), value, READ16LE(&gGba.mem.ioMem.b[COMM_SIOCNT]));
                        //st2 = st; //not needed to be set?
                    }
            }
#endif
            
            //Moving this to the bottom might prevent Mario Golf Adv from Occasionally Not Detecting wireless adapter
            if (value & 8) //Transfer Enable Flag Send (SO.bit.3, 1=Disable Transfer/Not Ready)
                value &= 0xfffb; //Transfer enable flag receive (0=Enable Transfer/Ready, SI.bit.2=SO.bit.3 of otherside)	// A kind of acknowledge procedure
            else //(SO.Bit.3, 0=Enable Transfer/Ready)
                value |= 4; //SI.bit.2=1 (otherside is Not Ready)
            
            if ((value & 5)==1)
                value |= 0x02; //wireless always use 2Mhz speed right? this will fix MarioGolfAdv Not Detecting wireless
            
            if (value & 0x80) //start/busy bit
            {
                if ((value & 3) == 1) //internal clock w/ 256KHz speed
                    rfu_transfer_end = 2048;
                else //external clock or any clock w/ 2MHz speed
                    rfu_transfer_end = 256;
                
                u16 a = READ16LE(&gGba.mem.ioMem.b[COMM_SIODATA32_H]);
                
#ifdef GBA_LOGGING
                if(systemVerbose & VERBOSE_LINK) {
                    if(rfulogd)
                        st.AppendFormat(_T("    %08X"), READ32LE(&gGba.mem.ioMem.b[COMM_SIODATA32_L])); else
                            st.Format(_T("%08X : %04X[%04X]    %08X"), GetTickCount(), value, READ16LE(&gGba.mem.ioMem.b[COMM_SIOCNT]), READ32LE(&gGba.mem.ioMem.b[COMM_SIODATA32_L]));
                    //st = st2;
                    logstartd = true;
                }
#endif
                
                printf("RFU_State: %d\n", rfu_state);
                
                
                switch (rfu_state) {
                    case RFU_INIT:
                        
                        printf("RFU_INIT\n");
                        
                        if (READ32LE(&gGba.mem.ioMem.b[COMM_SIODATA32_L]) == 0xb0bb8001 /*|| READ32LE(&gGba.mem.ioMem.b[COMM_SIODATA32_L]) == 0x7FFE8001 || READ32LE(&gGba.mem.ioMem.b[COMM_SIODATA32_L]) == 0x80017FFE || READ32LE(&gGba.mem.ioMem.b[COMM_SIODATA32_L]) == 0x8001B0BB*/) { //
                            
                            printf("YES IT WORKED\n");
                            
                            rfu_state = RFU_COMM;	// end of startup
                            rfu_initialized = true;
                            value &= 0xfffb; //0xff7b; //Bit.2 need to be 0 to indicate a finished initialization to fix MarioGolfAdv from occasionally Not Detecting wireless adapter (prevent it from sending 0x7FFE8001 comm)?
                            rfu_polarity = 0; //not needed?
                            //RFUClear();
                        }
                        rfu_buf = (READ16LE(&gGba.mem.ioMem.b[COMM_SIODATA32_L])<<16)|a;
                        break;
                        
                    case RFU_COMM:
                        
                        printf("RFU_COMM\n");
                        
                        CurCOM = READ32LE(&gGba.mem.ioMem.b[COMM_SIODATA32_L]);
                        if (a == 0x9966) //initialize cmd
                        {
                            u8 tmpcmd = CurCOM;
                            if(tmpcmd!=0x10 && tmpcmd!=0x11 && tmpcmd!=0x13 && tmpcmd!=0x14 && tmpcmd!=0x16 && tmpcmd!=0x17 && tmpcmd!=0x19 && tmpcmd!=0x1a && tmpcmd!=0x1b && tmpcmd!=0x1c && tmpcmd!=0x1d && tmpcmd!=0x1e && tmpcmd!=0x1f && tmpcmd!=0x20 && tmpcmd!=0x21 && tmpcmd!=0x24 && tmpcmd!=0x25 && tmpcmd!=0x26 && tmpcmd!=0x27 && tmpcmd!=0x30  && tmpcmd!=0x32 && tmpcmd!=0x33 && tmpcmd!=0x34 && tmpcmd!=0x3d && tmpcmd!=0xa8 && tmpcmd!=0xee) {
                                //log("%08X : UnkCMD %08X  %04X  %08X %08X\n", GetTickCount(), CurCOM, PrevVAL, PrevCOM, PrevDAT);
                                //systemVerbose |= VERBOSE_LINK; //for testing only
                            }
                            
                            //rfu_qrecv = 0;
                            rfu_counter = 0;
                            if ((rfu_qsend2=rfu_qsend=gGba.mem.ioMem.b[0x121]) != 0) { //COMM_SIODATA32_L+1, following data [to send]
                                rfu_state = RFU_SEND;
                                //rfu_counter = 0;
                            }
                            
                            if ((rfu_cmd|0x80)!=0x91 && (rfu_cmd|0x80)!=0x93 && ((rfu_cmd|0x80)<0xa4 || (rfu_cmd|0x80)>0xa8)) rfu_lastcmd3 = rfu_cmd;
                            
                            if(gGba.mem.ioMem.b[COMM_SIODATA32_L] == 0xee) { //0xee cmd shouldn't override previous cmd
                                rfu_lastcmd = rfu_cmd2;
                                rfu_cmd2 = gGba.mem.ioMem.b[COMM_SIODATA32_L];
                                //rfu_polarity = 0; //when polarity back to normal the game can initiate a new cmd even when 0xee hasn't been finalized, but it looks improper isn't?
                            } else {
                                rfu_lastcmd = rfu_cmd;
                                rfu_cmd = gGba.mem.ioMem.b[COMM_SIODATA32_L];
                                rfu_cmd2 = 0;
                                
                                int maskid;
                                if (rfu_cmd==0x27 || rfu_cmd==0x37) {
                                    rfu_lastcmd2 = rfu_cmd;
                                    //rfu_transfer_end = 1;
                                    rfu_lasttime = GetTickCount();
                                } else
                                    if (rfu_cmd==0x24) { //non-important data shouldn't overwrite important data from 0x25
                                        rfu_lastcmd2 = rfu_cmd;
                                        rfu_cansend = false;
                                        //rfu_transfer_end = 1;
                                        if(rfu_ishost)
                                            maskid = ~linkmem.rfu_request[vbaid]; else
                                                maskid = ~(1<<gbaid);
                                        //previous important data need to be received successfully before sending another important data
                                        rfu_lasttime = GetTickCount(); //just to mark the last time a data being sent
                                        if(!lanlink.speed) {
                                            while (!AppTerminated && linkmem.numgbas>=2 && linkmem.rfu_q[vbaid]>1 && vbaid!=gbaid && linkmem.rfu_signal[vbaid] && linkmem.rfu_signal[gbaid] && (GetTickCount()-rfu_lasttime)<(unsigned long)linktimeout) { //2 players
                                                if(!rfu_ishost)
                                                    SetEvent(linksync[gbaid]); else //unlock other gba, allow other gba to move (sending their data)  //is max value of vbaid=1 ?
                                                        for(int j=0;j<linkmem.numgbas;j++)
                                                            if(j!=vbaid) SetEvent(linksync[j]);
                                                WaitForSingleObject(linksync[vbaid], 1); //linktimeout //wait until this gba allowed to move (to prevent both GBAs from using 0x25 at the same time)
                                                ResetEvent(linksync[vbaid]); //lock this gba, don't allow this gba to move (prevent sending another data too fast w/o giving the other side chances to read it)
                                                
                                                //if(PeekMessage(&msg, 0, 0, 0, PM_NOREMOVE)) { //theApp.GetMainWnd()->GetSafeHwnd()
                                                //	if(msg.message==WM_CLOSE) AppTerminated=true; else theApp.PumpMessage(); //seems to be processing message only if it has message otherwise it halt the program
                                                //}
                                                //SleepEx(1,true);
                                                if (!rfu_ishost && linkmem.rfu_request[vbaid]) {
                                                    c_s.Lock();
                                                    linkmem.rfu_request[vbaid] = 0;
                                                    c_s.Unlock();
                                                    break;
                                                } //workaround for a bug where rfu_request failed to reset when GBA act as client
                                            }
                                            //SetEvent(linksync[vbaid]); //set again to reduce the lag since it will be waited again during finalization cmd
                                        } else {
                                            if(linkmem.numgbas>=2 && gbaid!=vbaid && linkmem.rfu_q[vbaid]>1 && linkmem.rfu_signal[vbaid] && linkmem.rfu_signal[gbaid]) { //2 players connected
                                                if(!rfu_ishost)
                                                    SetEvent(linksync[gbaid]); else //unlock other gba, allow other gba to move (sending their data)  //is max value of vbaid=1 ?
                                                        for(int j=0;j<linkmem.numgbas;j++)
                                                            if(j!=vbaid) SetEvent(linksync[j]);
                                                WaitForSingleObject(linksync[vbaid], lanlink.speed?1:linktimeout); //linktimeout //wait until this gba allowed to move
                                                ResetEvent(linksync[vbaid]); //lock this gba, don't allow this gba to move (prevent sending another data too fast w/o giving the other side chances to read it)
                                            }
                                        }
                                        if(linkmem.rfu_q[vbaid]<2 /*|| (!linkmem.rfu_proto[vbaid] && linkmem.rfu_q[vbaid]<=rfu_qsend)*/) { //can overwrite now
                                            rfu_cansend = true;
                                            c_s.Lock();
                                            linkmem.rfu_q[vbaid] = 0; //rfu_qsend;
                                            linkmem.rfu_qid[vbaid] = 0; //
                                            c_s.Unlock();
                                        } else if(!lanlink.speed) rfu_waiting = true; //log("%08X  CMD24: %d %d\n",GetTickCount(),linkmem.rfu_q[vbaid],rfu_qsend2); //don't wait with speedhack
                                    } else
                                        if (rfu_cmd==0x25 || rfu_cmd==0x35 /*|| (rfu_cmd==0x24 && linkmem.rfu_q[vbaid]<=rfu_qsend)*/) { //&& linkmem.rfu_q[vbaid]>1
                                            rfu_lastcmd2 = rfu_cmd;
                                            rfu_cansend = false;
                                            //rfu_transfer_end = 1;
                                            if(rfu_ishost)
                                                maskid = ~linkmem.rfu_request[vbaid]; else
                                                    maskid = ~(1<<gbaid);
                                            //previous important data need to be received successfully before sending another important data
                                            rfu_lasttime = GetTickCount();
                                            if(!lanlink.speed) {
                                                while (!AppTerminated && linkmem.numgbas>=2 && linkmem.rfu_q[vbaid]>1 && vbaid!=gbaid && linkmem.rfu_signal[vbaid] && linkmem.rfu_signal[gbaid] && (GetTickCount()-rfu_lasttime)<(unsigned long)linktimeout) { //2 players
                                                    if(!rfu_ishost)
                                                        SetEvent(linksync[gbaid]); else //unlock other gba, allow other gba to move (sending their data)  //is max value of vbaid=1 ?
                                                            for(int j=0;j<linkmem.numgbas;j++)
                                                                if(j!=vbaid) SetEvent(linksync[j]);
                                                    WaitForSingleObject(linksync[vbaid], 1); //linktimeout //wait until this gba allowed to move (to prevent both GBAs from using 0x25 at the same time)
                                                    ResetEvent(linksync[vbaid]); //lock this gba, don't allow this gba to move (prevent sending another data too fast w/o giving the other side chances to read it)
                                                    
                                                    //if(PeekMessage(&msg, 0, 0, 0, PM_NOREMOVE)) { //theApp.GetMainWnd()->GetSafeHwnd()
                                                    //	if(msg.message==WM_CLOSE) AppTerminated=true; else theApp.PumpMessage(); //seems to be processing message only if it has message otherwise it halt the program
                                                    //}
                                                    //SleepEx(1,true);
                                                    if (!rfu_ishost && linkmem.rfu_request[vbaid]) {
                                                        c_s.Lock();
                                                        linkmem.rfu_request[vbaid] = 0;
                                                        c_s.Unlock();
                                                        break;
                                                    } //workaround for a bug where rfu_request failed to reset when GBA act as client
                                                }
                                                //SetEvent(linksync[vbaid]); //set again to reduce the lag since it will be waited again during finalization cmd
                                            } else {
                                                if(linkmem.numgbas>=2 && gbaid!=vbaid && linkmem.rfu_q[vbaid]>1 && linkmem.rfu_signal[vbaid] && linkmem.rfu_signal[gbaid]) { //2 players connected
                                                    if(!rfu_ishost)
                                                        SetEvent(linksync[gbaid]); else //unlock other gba, allow other gba to move (sending their data)  //is max value of vbaid=1 ?
                                                            for(int j=0;j<linkmem.numgbas;j++)
                                                                if(j!=vbaid) SetEvent(linksync[j]);
                                                    WaitForSingleObject(linksync[vbaid], lanlink.speed?1:linktimeout); //linktimeout //wait until this gba allowed to move
                                                    ResetEvent(linksync[vbaid]); //lock this gba, don't allow this gba to move (prevent sending another data too fast w/o giving the other side chances to read it)
                                                }
                                            }
                                            if(linkmem.rfu_q[vbaid]<2) {
                                                rfu_cansend = true;
                                                c_s.Lock();
                                                linkmem.rfu_q[vbaid] = 0; //rfu_qsend;
                                                linkmem.rfu_qid[vbaid] = 0; //
                                                c_s.Unlock();
                                            } else if(!lanlink.speed) rfu_waiting = true; //log("%08X  CMD25: %d %d\n",GetTickCount(),linkmem.rfu_q[vbaid],rfu_qsend2); //don't wait with speedhack
                                        } else
                                            if (rfu_cmd==0xa8 || rfu_cmd==0xb6 || rfu_cmd==0x11 || rfu_cmd==0x26) { // && numtransfers == 1
                                                //rfu_transfer_end = 1;
                                            } else
                                                if (rfu_cmd == 0x11 || rfu_cmd == 0x1a || rfu_cmd == 0x26) {
                                                    //rfu_transfer_end = 2048;
                                                    //rfu_lasttime = GetTickCount();
                                                    if(rfu_lastcmd2==0x24)
                                                        rfu_waiting = true;
                                                }
                            }
                            //UPDATE_REG(COMM_SIODATA32_L, 0);
                            //UPDATE_REG(COMM_SIODATA32_H, 0x8000);
                            if(rfu_waiting) rfu_buf = READ32LE(&gGba.mem.ioMem.b[COMM_SIODATA32_L]); else
                                rfu_buf = 0x80000000;
                        }
                        else if (a == 0x8000) //finalize cmd, the game will send this when polarity reversed (expecting something)
                        {
                            rfu_qrecv = 0;
                            //rfu_counter = 0;
                            if(rfu_cmd2 == 0xee) {
                                if(rfu_masterdata[0] == 2) //is this value of 2 related to polarity?
                                    rfu_polarity = 0; //to normalize polarity after finalize looks more proper
                                //UPDATE_REG(COMM_SIODATA32_H, 0x9966);
                                //UPDATE_REG(COMM_SIODATA32_L, (rfu_qrecv<<8) | (rfu_cmd2^0x80));
                                rfu_buf = 0x99660000|(rfu_qrecv<<8) | (rfu_cmd2^0x80);
                            } else {
                                switch (rfu_cmd) {
                                    case 0x1a:	// check if someone joined
                                        //gbaid = vbaid; //1-vbaid;
                                        if (linkmem.rfu_request[vbaid]) {
                                            //gbaid = vbaid^1; //1-vbaid; //linkmem.rfu_request[vbaid] & 1;
                                            gbaidx = gbaid;
                                            do {
                                                gbaidx = (gbaidx+1) % linkmem.numgbas;
                                                if (gbaidx!=vbaid && linkmem.rfu_reqid[gbaidx]==(vbaid<<3)+0x61f1) rfu_masterdata[rfu_qrecv++] = (gbaidx<<3)+0x61f1;
                                            } while (gbaidx!=gbaid && linkmem.numgbas>=2); // && linkmem.rfu_reqid[gbaidx]!=(vbaid<<3)+0x61f1
                                            if (rfu_qrecv>0) {
                                                bool ok = false;
                                                for(int i=0; i<rfu_numclients; i++)
                                                    if((rfu_clientlist[i] & 0xffff)==rfu_masterdata[0/*rfu_qrecv-1*/]) {ok = true; break;}
                                                if(!ok) {
                                                    rfu_curclient = rfu_numclients;
                                                    gbaid = ((rfu_masterdata[0]&0xffff)-0x61f1)>>3; //last joined id
                                                    c_s.Lock();
                                                    linkmem.rfu_signal[gbaid] = 0xffffffff>>((3-(rfu_numclients))<<3);
                                                    linkmem.rfu_clientidx[gbaid] = rfu_numclients;
                                                    c_s.Unlock();
                                                    rfu_clientlist[rfu_numclients] = rfu_masterdata[0/*rfu_qrecv-1*/] | (rfu_numclients++ << 16);
                                                    //rfu_numclients++;
                                                    //log("%d  Switch%02X:%d\n",GetTickCount(),rfu_cmd,gbaid);
                                                    rfu_masterq = 1; //data size
                                                    outbuffer[1] = 0x80|vbaid; //'W'; //destination GBA ID (needed for routing), if dest id = vbaid then it's a broadcast
                                                    outbuffer[0] = (rfu_masterq+2)<<2; //total size including headers //vbaid;
                                                    outbuffer[2] = rfu_cmd;
                                                    outbuffer[3] = rfu_masterq+1;
                                                    memcpy(&outbuffer[4],&linkmem.rfu_signal[gbaid],4);
                                                    memcpy(&outbuffer[8],&rfu_clientlist[rfu_numclients-1],rfu_masterq<<2); //data size (excluding headers)
                                                    LinkSendData(outbuffer, (rfu_masterq+2)<<2, RetryCount, 0); //broadcast
                                                }
                                                if(gbaid==vbaid) {
                                                    gbaid = ((rfu_masterdata[0]&0xffff)-0x61f1)>>3; //gbaidx;
                                                }
                                                rfu_state = RFU_RECV;
                                            }
                                        }
                                        if(rfu_numclients>0) {
                                            for(int i=0; i<rfu_numclients; i++) rfu_masterdata[i] = rfu_clientlist[i];
                                        }
                                        rfu_id = (gbaid<<3)+0x61f1;
                                        rfu_cmd ^= 0x80;
                                        break;
                                        
                                    case 0x1f: //join a room as client
                                        rfu_id = rfu_masterdata[0]; //TODO: check why rfu_id = 0x0420 ?? and causing gbaid to be wrong also
                                        if(rfu_id<0x61f1)
                                            //log("Invalid ID: %04X\n",rfu_id);
                                        gbaid = (rfu_id-0x61f1)>>3;
                                        rfu_idx = rfu_id;
                                        gbaidx = gbaid;
                                        rfu_lastcmd2 = 0;
                                        numtransfers = 0;
                                        c_s.Lock();
                                        linkmem.rfu_q[vbaid] = 0; //to prevent leftover data from previous session received immediately in the new session
                                        linkmem.rfu_reqid[vbaid] = rfu_id;
                                        linkmem.rfu_request[vbaid] = 0; //TODO:might failed to reset rfu_request when being accessed by otherside at the same time, sometimes both acting as client but one of them still have request[vbaid]!=0 //to prevent both GBAs from acting as Host, client can't be a host at the same time
                                        c_s.Unlock();
                                        if(vbaid!=gbaid) {
                                            //if(linkmem.rfu_request[gbaid]) numtransfers++; //if another client already joined
                                            /*if(!linkmem.rfu_request[gbaid]) rfu_isfirst = true;
                                             linkmem.rfu_signal[vbaid] = 0x00ff;
                                             linkmem.rfu_request[gbaid] |= 1<<vbaid;*/ // tells the other GBA(a host) that someone(a client) is joining
                                            rfu_masterq = 1; //data size
                                            outbuffer[1] = 0x80|gbaid; //'W'; //destination GBA ID (needed for routing), if dest id = vbaid then it's a broadcast
                                            outbuffer[0] = (rfu_masterq+1)<<2; //total size including headers //vbaid;
                                            outbuffer[2] = rfu_cmd;
                                            outbuffer[3] = rfu_masterq;
                                            memcpy(&outbuffer[4],rfu_masterdata,rfu_masterq<<2); //data size (excluding headers)
                                            LinkSendData(outbuffer, (rfu_masterq+1)<<2, RetryCount, 0); //broadcast
                                        }
                                        rfu_cmd ^= 0x80;
                                        break;
                                        
                                    case 0x1e:	// receive broadcast data
                                        numtransfers = 0;
                                        rfu_numclients = 0;
                                        c_s.Lock();
                                        //linkmem.rfu_request[vbaid] = 0; //to prevent both GBAs from acting as Host and thinking both of them have Client?
                                        linkmem.rfu_q[vbaid] = 0; //to prevent leftover data from previous session received immediately in the new session
                                        c_s.Unlock();
                                    case 0x1d:	// no visible difference
                                        c_s.Lock();
                                        linkmem.rfu_request[vbaid] = 0; //to prevent both GBAs from acting as Host and thinking both of them have Client?
                                        c_s.Unlock();
                                        memset(rfu_masterdata, 0, sizeof(linkmem.rfu_bdata[vbaid])); //may not be needed
                                        rfu_qrecv = 0;
                                        for(int i=0; i<linkmem.numgbas; i++)
                                            if(i!=vbaid && linkmem.rfu_bdata[i][0]) {
                                                memcpy(&rfu_masterdata[rfu_qrecv], linkmem.rfu_bdata[i], sizeof(linkmem.rfu_bdata[i]));
                                                rfu_qrecv += 7;
                                            }
                                        //if(rfu_qrecv==0) rfu_qrecv = 7; //is this needed? to prevent MarioGolfAdv from joining it's own room when switching from host to client mode due to left over room data in the game buffer?
                                        if (rfu_qrecv>0)
                                            rfu_state = RFU_RECV;
                                        rfu_polarity = 0;
                                        rfu_counter = 0;
                                        rfu_cmd ^= 0x80;
                                        break;
                                        
                                    case 0x16:	// send broadcast data (ie. room name)
                                        c_s.Lock();
                                        memcpy(&linkmem.rfu_bdata[vbaid][1], &rfu_masterdata[1], sizeof(linkmem.rfu_bdata[vbaid])-4);
                                        //linkmem.rfu_bdata[vbaid][0] = (vbaid<<3)+0x61f1; //start broadcasting here may cause client to join other client in pokemon coloseum
                                        //linkmem.rfu_q[vbaid] = 0;
                                        c_s.Unlock();
                                        rfu_masterq = (sizeof(linkmem.rfu_bdata[vbaid]) >> 2)-1; //(sizeof(linkmem.rfu_bdata[vbaid])+3) >> 2; //7 dwords
                                        outbuffer[1] = 0x80|vbaid; //'W'; //destination GBA ID (needed for routing), if dest id = vbaid then it's a broadcast
                                        outbuffer[0] = (rfu_masterq+1)<<2; //total size including headers //vbaid;
                                        outbuffer[2] = rfu_cmd;
                                        outbuffer[3] = rfu_masterq;
                                        memcpy(&outbuffer[4],&rfu_masterdata[1],rfu_masterq<<2); //data size (excluding headers)
                                        LinkSendData(outbuffer, (rfu_masterq+1)<<2, RetryCount, 0); //broadcast
                                        rfu_cmd ^= 0x80;
                                        break;
                                        
                                    case 0x11:	// get signal strength
                                        //check signal
                                        c_s.Lock();
                                        if(linkmem.numgbas>=2 && (linkmem.rfu_request[vbaid]|linkmem.rfu_request[gbaid])) //signal only good when connected
                                            if(rfu_ishost) { //update, just incase there are leaving clients
                                                u8 rfureq = linkmem.rfu_request[vbaid];
                                                u8 oldnum = rfu_numclients;
                                                rfu_numclients = 0;
                                                for(int i=0; i<8; i++) {
                                                    if(rfureq & 1) rfu_numclients++;
                                                    rfureq >>= 1;
                                                }
                                                if(rfu_numclients>oldnum) rfu_numclients = oldnum; //must not be higher than old value, which means the new client haven't been processed by 0x1a cmd yet
                                                linkmem.rfu_signal[vbaid] = /*0x00ff*/ 0xffffffff>>((4-rfu_numclients)<<3);
                                            } else linkmem.rfu_signal[vbaid] = linkmem.rfu_signal[gbaid]; // /*0x0ff << (linkmem.rfu_clientidx[vbaid]<<3)*/ 0xffffffff>>((3-linkmem.rfu_clientidx[vbaid])<<3);
                                            else linkmem.rfu_signal[vbaid] = 0;
                                        c_s.Unlock();
                                        if (rfu_qrecv==0) {
                                            rfu_qrecv = 1;
                                            rfu_masterdata[0] = (u32)linkmem.rfu_signal[vbaid];
                                        }
                                        if (rfu_qrecv>0) {
                                            rfu_state = RFU_RECV; //3;
                                            int hid = vbaid;
                                            if(!rfu_ishost) hid = gbaid;
                                            rfu_masterdata[rfu_qrecv-1] = (u32)linkmem.rfu_signal[hid/*vbaid*//*gbaid*/]; //
                                        }
                                        //rfu_transfer_end = 1;
                                        rfu_cmd ^= 0x80;
                                        break;
                                        
                                    case 0x33:	// rejoin status check?
                                        if(linkmem.rfu_signal[vbaid] || numtransfers==0/*|| linkmem.numgbas>=2*/)
                                            rfu_masterdata[0] = 0; else //0=success
                                                rfu_masterdata[0] = (u32)-1; //0xffffffff; //1=failed, 2++ = reserved/invalid, we use invalid value to let the game retries 0x33 until signal restored
                                        //numtransfers = 0;
                                        //linktime = 1;
                                        rfu_cmd ^= 0x80;
                                        //rfu_polarity = 0;
                                        rfu_state = RFU_RECV; //3;
                                        rfu_qrecv = 1;
                                        break;
                                        
                                    case 0x14:	// reset current client index and error check?
                                        if((linkmem.rfu_signal[vbaid] || numtransfers==0/*|| linkmem.numgbas>=2*/) && gbaid!=vbaid)
                                            rfu_masterdata[0] = ((!rfu_ishost?0x100:0+linkmem.rfu_clientidx[gbaid]) << 16)|((gbaid<<3)+0x61f1); //(linkmem.rfu_clientidx[gbaid] << 16)|((gbaid<<3)+0x61f1); /*0x02001234;*/ else //high word should be 0x0200 ? is 0x0200 means 1st client and 0x4000 means 2nd client?
                                        rfu_masterdata[0] = 0; //0=error, non-zero=good?
                                        //numtransfers = 0;
                                        //linktime = 1;
                                        rfu_cmd ^= 0x80;
                                        //rfu_polarity = 0;
                                        rfu_state = RFU_RECV; //3;
                                        rfu_qrecv = 1;
                                        break;
                                        
                                    case 0x13:	// error check?
                                        if(linkmem.rfu_signal[vbaid] || numtransfers==0 || rfu_initialized /*|| linkmem.numgbas>=2*/)
                                            rfu_masterdata[0] = ((rfu_ishost?0x100:0+linkmem.rfu_clientidx[vbaid]) << 16)|((vbaid<<3)+0x61f1); /*0x02001234;*/ else //high word should be 0x0200 ? is 0x0200 means 1st client and 0x4000 means 2nd client?
                                                rfu_masterdata[0] = 0; //0=error, non-zero=good?
                                        //numtransfers = 0;
                                        //linktime = 1;
                                        rfu_cmd ^= 0x80;
                                        //rfu_polarity = 0;
                                        rfu_state = RFU_RECV; //3;
                                        rfu_qrecv = 1;
                                        break;
                                        
                                    case 0x20:	// client, this has something to do with 0x1f
                                        rfu_masterdata[0] = (linkmem.rfu_clientidx[vbaid]) << 16; //needed for client
                                        rfu_masterdata[0] |= (vbaid<<3)+0x61f1; //0x1234; //0x641b; //max id value? Encryption key or Station Mode? (0xFBD9/0xDEAD=Access Point mode?)
                                        c_s.Lock();
                                        linkmem.rfu_q[vbaid] = 0; //to prevent leftover data from previous session received immediately in the new session
                                        linkmem.rfu_request[vbaid] = 0; //TODO:may not works properly, sometimes both acting as client but one of them still have request[vbaid]!=0 //to prevent both GBAs from acting as Host, client can't be a host at the same time
                                        if(linkmem.rfu_signal[gbaid]<linkmem.rfu_signal[vbaid]) //TODO: why sometimes gbaid and rfu_id is invalid number ?? (rfu_id = 0x0420 causing gbaid to be wrong also)
                                            linkmem.rfu_signal[gbaid] = linkmem.rfu_signal[vbaid];
                                        c_s.Unlock();
                                        rfu_polarity = 0;
                                        rfu_state = RFU_RECV; //3;
                                        rfu_qrecv = 1;
                                        rfu_cmd ^= 0x80;
                                        break;
                                    case 0x21:	// client, this too
                                        rfu_masterdata[0] = (linkmem.rfu_clientidx[vbaid]) << 16; //not needed?
                                        rfu_masterdata[0] |= (vbaid<<3)+0x61f1; //0x641b; //max id value? Encryption key or Station Mode? (0xFBD9/0xDEAD=Access Point mode?)
                                        c_s.Lock();
                                        linkmem.rfu_q[vbaid] = 0; //to prevent leftover data from previous session received immediately in the new session
                                        linkmem.rfu_request[vbaid] = 0; //TODO:may not works properly, sometimes both acting as client but one of them still have request[vbaid]!=0 //to prevent both GBAs from acting as Host, client can't be a host at the same time
                                        c_s.Unlock();
                                        rfu_polarity = 0;
                                        rfu_state = RFU_RECV; //3;
                                        rfu_qrecv = 1;
                                        rfu_cmd ^= 0x80;
                                        break;
                                        
                                    case 0x19:	// server bind/start listening for client to join, may be used in the middle of host<->client communication w/o causing clients to dc?
                                        c_s.Lock();
                                        //linkmem.rfu_request[vbaid] = 0; //to prevent both GBAs from acting as Host and thinking both of them have Client?
                                        linkmem.rfu_q[vbaid] = 0; //to prevent leftover data from previous session received immediately in the new session
                                        linkmem.rfu_bdata[vbaid][0] = (vbaid<<3)+0x61f1; //start broadcasting room name
                                        linkmem.rfu_clientidx[vbaid] = 0;
                                        c_s.Unlock();
                                        //numtransfers = 0;
                                        //rfu_numclients = 0;
                                        //rfu_curclient = 0;
                                        //rfu_lastcmd2 = 0;
                                        //rfu_polarity = 0;
                                        rfu_ishost = true;
                                        rfu_isfirst = false;
                                        rfu_masterq = 1; //data size
                                        outbuffer[1] = 0x80|vbaid; //'W'; //destination GBA ID (needed for routing), if dest id = vbaid then it's a broadcast
                                        outbuffer[0] = (rfu_masterq+1)<<2; //total size including headers //vbaid;
                                        outbuffer[2] = rfu_cmd;
                                        outbuffer[3] = rfu_masterq;
                                        memcpy(&outbuffer[4],linkmem.rfu_bdata[vbaid],rfu_masterq<<2); //data size (excluding headers)
                                        LinkSendData(outbuffer, (rfu_masterq+1)<<2, RetryCount, 0); //broadcast
                                        rfu_cmd ^= 0x80;
                                        break;
                                        
                                    case 0x1c:	//client, might reset some data?
                                        //linkmem.rfu_request[vbaid] = 0; //to prevent both GBAs from acting as Host and thinking both of them have Client
                                        //linkmem.rfu_bdata[vbaid][0] = 0; //stop broadcasting room name
                                        rfu_ishost = false; //TODO: prevent both GBAs act as client but one of them have rfu_request[vbaid]!=0 on MarioGolfAdv lobby
                                        //rfu_polarity = 0;
                                        rfu_numclients = 0;
                                        rfu_curclient = 0;
                                        //TODO: is this the cause why rfu_id became 0x0420 ?? and causing gbaid to be wrong also
                                        //LinkDiscardData(0);
                                        c_s.Lock();
                                        //linkmem.rfu_listfront[vbaid] = 0;
                                        //linkmem.rfu_listback[vbaid] = 0;
                                        DATALIST.clear();
                                        linkmem.rfu_clientidx[vbaid] = 0xff00; //highest byte need to be non-zero to make 0x20 cmd to be called repeatedly until join request(0x1f) approved by 0x1a cmd
                                        c_s.Unlock();
                                        rfu_cmd ^= 0x80;
                                        break;
                                        
                                    case 0x1b:	//host, might reset some data? may be used in the middle of host<->client communication w/o causing clients to dc?
                                        c_s.Lock();
                                        //linkmem.rfu_request[vbaid] = 0; //to prevent both GBAs from acting as Client and thinking one of them is a Host?
                                        linkmem.rfu_bdata[vbaid][0] = 0; //0 may cause player unable to join in pokemon union room?
                                        c_s.Unlock();
                                        //numtransfers = 0;
                                        //linktime = 1;
                                        rfu_masterq = 1; //data size
                                        outbuffer[1] = 0x80|vbaid; //'W'; //destination GBA ID (needed for routing), if dest id = vbaid then it's a broadcast
                                        outbuffer[0] = (rfu_masterq+1)<<2; //total size including headers //vbaid;
                                        outbuffer[2] = rfu_cmd;
                                        outbuffer[3] = rfu_masterq;
                                        memcpy(&outbuffer[4],linkmem.rfu_bdata[vbaid],rfu_masterq<<2); //data size (excluding headers)
                                        LinkSendData(outbuffer, (rfu_masterq+1)<<2, RetryCount, 0); //broadcast
                                        rfu_cmd ^= 0x80;
                                        break;
                                        
                                    case 0x30: //reset some data
                                        if(vbaid!=gbaid) { //(linkmem.numgbas >= 2)
                                            c_s.Lock();
                                            //linkmem.rfu_signal[gbaid] = 0;
                                            linkmem.rfu_request[gbaid] &= ~(1<<vbaid); //linkmem.rfu_request[gbaid] = 0;
                                            SetEvent(linksync[gbaid]); //allow other gba to move
                                            c_s.Unlock();
                                        }
                                        //WaitForSingleObject(linksync[vbaid], 40/*linktimeout*/);
                                        while (linkmem.rfu_signal[vbaid]) {
                                            WaitForSingleObject(linksync[vbaid], 1/*linktimeout*/);
                                            c_s.Lock();
                                            linkmem.rfu_signal[vbaid] = 0;
                                            linkmem.rfu_request[vbaid] = 0; //There is a possibility where rfu_request/signal didn't get zeroed here when it's being read by the other GBA at the same time
                                            c_s.Unlock();
                                            //SleepEx(1,true);
                                        }
                                        c_s.Lock();
                                        //linkmem.rfu_listfront[vbaid] = 0;
                                        //linkmem.rfu_listback[vbaid] = 0;
                                        DATALIST.clear();
                                        //linkmem.rfu_clientidx[vbaid] = 0xff00; //highest byte need to be non-zero to make 0x20 cmd to be called repeatedly until join request(0x1f) approved by 0x1a cmd
                                        //linkmem.rfu_q[vbaid] = 0;
                                        linkmem.rfu_proto[vbaid] = 0;
                                        linkmem.rfu_reqid[vbaid] = 0;
                                        linkmem.rfu_linktime[vbaid] = 0;
                                        linkmem.rfu_gdata[vbaid] = 0;
                                        linkmem.rfu_bdata[vbaid][0] = 0;
                                        c_s.Unlock();
                                        rfu_polarity = 0; //is this included?
                                        //linkid = -1; //0;
                                        numtransfers = 0;
                                        rfu_numclients = 0;
                                        rfu_curclient = 0;
                                        linktime = 1; //0; //reset here instead of at 0x24/0xa5/0xa7
                                        /*rfu_id = 0;
                                         rfu_idx = 0;
                                         gbaid = vbaid;
                                         gbaidx = gbaid;
                                         rfu_ishost = false;
                                         rfu_isfirst = false;*/
                                        rfu_cmd ^= 0x80;
                                        SetEvent(linksync[vbaid]); //may not be needed
                                        break;
                                        
                                    case 0x3d:	// init/reset rfu data
                                        rfu_initialized = false;
                                    case 0x10:	// init/reset rfu data
                                        if(vbaid!=gbaid) { //(linkmem.numgbas >= 2)
                                            c_s.Lock();
                                            //linkmem.rfu_signal[gbaid] = 0;
                                            linkmem.rfu_request[gbaid] &= ~(1<<vbaid); //linkmem.rfu_request[gbaid] = 0;
                                            SetEvent(linksync[gbaid]); //allow other gba to move
                                            c_s.Unlock();
                                        }
                                        //WaitForSingleObject(linksync[vbaid], 40/*linktimeout*/);
                                        while (linkmem.rfu_signal[vbaid]) {
                                            WaitForSingleObject(linksync[vbaid], 1/*linktimeout*/);
                                            c_s.Lock();
                                            linkmem.rfu_signal[vbaid] = 0;
                                            linkmem.rfu_request[vbaid] = 0; //There is a possibility where rfu_request/signal didn't get zeroed here when it's being read by the other GBA at the same time
                                            c_s.Unlock();
                                            //SleepEx(1,true);
                                        }
                                        c_s.Lock();
                                        //linkmem.rfu_listfront[vbaid] = 0;
                                        //linkmem.rfu_listback[vbaid] = 0;
                                        DATALIST.clear();
                                        //linkmem.rfu_clientidx[vbaid] = 0xff00; //highest byte need to be non-zero to make 0x20 cmd to be called repeatedly until join request(0x1f) approved by 0x1a cmd
                                        //linkmem.rfu_q[vbaid] = 0;
                                        linkmem.rfu_proto[vbaid] = 0;
                                        linkmem.rfu_reqid[vbaid] = 0;
                                        linkmem.rfu_linktime[vbaid] = 0;
                                        linkmem.rfu_gdata[vbaid] = 0;
                                        linkmem.rfu_bdata[vbaid][0] = 0;
                                        linkmem.rfu_clientidx[vbaid] = 0xff00; //highest byte need to be non-zero to make 0x20 cmd to be called repeatedly until join request(0x1f) approved by 0x1a cmd
                                        c_s.Unlock();
                                        rfu_polarity = 0; //is this included?
                                        //linkid = -1; //0;
                                        numtransfers = 0;
                                        rfu_numclients = 0;
                                        rfu_curclient = 0;
                                        linktime = 1; //0; //reset here instead of at 0x24/0xa5/0xa7
                                        rfu_id = 0;
                                        rfu_idx = 0;
                                        gbaid = vbaid;
                                        gbaidx = gbaid;
                                        rfu_ishost = false;
                                        rfu_isfirst = false;
                                        rfu_qrecv = 0;
                                        SetEvent(linksync[vbaid]); //may not be needed
                                        rfu_cmd ^= 0x80;
                                        break;
                                        
                                    case 0x36: //does it expect data returned?
                                    case 0x26:
                                        //Switch remote id to available data
                                        bool ok;
                                        int ctr;
                                        ctr = 0;
                                        c_s.Lock();
                                        ok = !DATALIST.empty();
                                        c_s.Unlock();
                                        if(ok) 
                                            do { 
                                                c_s.Lock();
                                                tmpDataRec = DATALIST.front();
                                                c_s.Unlock();
                                                
                                                gbaid = tmpDataRec.gbaid;
                                                rfu_id = (gbaid<<3)+0x61f1;
                                                rfu_curclient = tmpDataRec.idx;
                                                
                                                ok = false;
                                                if(tmpDataRec.len!=rfu_qrecv) ok = true; else
                                                    if(memcmp(rfu_masterdata, tmpDataRec.data, tmpDataRec.len)!=0) ok = true;
                                                //for(int i=0; i<tmpDataRec.len; i++)
                                                //	if(tmpDataRec.data[i]!=rfu_masterdata[i]) {ok = true; break;}
                                                
                                                if(tmpDataRec.len==0 && ctr==0) ok = true;
                                                
                                                if(ok) //next data is not a duplicate of currently unprocessed data
                                                    if(rfu_qrecv<2 || tmpDataRec.len>1) 
                                                    {
                                                        if(rfu_qrecv>1) { //stop here if next data is different than currently unprocessed non-ping data
                                                            c_s.Lock();
                                                            linkmem.rfu_linktime[gbaid] = tmpDataRec.time;
                                                            c_s.Unlock();
                                                            break;
                                                        }
                                                        
                                                        if(tmpDataRec.len>=rfu_qrecv) {
                                                            //memcpy(linkmem.rfu_data[gbaid], tmpDataRec.data, 4*tmpDataRec.len);
                                                            //linkmem.rfu_qid[gbaid] = tmpDataRec.qid;
                                                            //linkmem.rfu_q[gbaid] = tmpDataRec.len;
                                                            rfu_masterq = rfu_qrecv = tmpDataRec.len;
                                                            
                                                            //if((linkmem.rfu_qid[gbaid] & (1<<vbaid))) //data is for this GBA
                                                            if(rfu_qrecv!=0) { //data size > 0
                                                                memcpy(rfu_masterdata, tmpDataRec.data/*linkmem.rfu_data[gbaid]*/, minimum((int)rfu_masterq<<2,(int)sizeof(rfu_masterdata))); //128 //read data from other GBA
                                                                //linkmem.rfu_qid[gbaid] &= ~(1<<vbaid); //mark as received by this GBA
                                                                //if(linkmem.rfu_request[gbaid]) linkmem.rfu_qid[gbaid] &= linkmem.rfu_request[gbaid]; //remask if it's host, just incase there are client leaving multiplayer
                                                                //if(!linkmem.rfu_qid[gbaid]) linkmem.rfu_q[gbaid] = 0; //mark that it has been fully received
                                                                //if(!linkmem.rfu_q[gbaid] || (rfu_ishost && linkmem.rfu_qid[gbaid]!=linkmem.rfu_request[gbaid])) SetEvent(linksync[gbaid]);
                                                                //linkmem.rfu_qid[gbaid] = 0;
                                                                //linkmem.rfu_q[gbaid] = 0;
                                                                //SetEvent(linksync[gbaid]);
                                                                //log("%08X  CMD26 Recv: %d %d\n",GetTickCount(),rfu_qrecv,linkmem.rfu_q[gbaid]);
                                                            }
                                                        }
                                                    } //else log("%08X  CMD26 Skip: %d %d %d\n",GetTickCount(),rfu_qrecv,linkmem.rfu_q[gbaid],tmpDataRec.len);
                                                
                                                ctr++;
                                                c_s.Lock();
                                                //linkmem.rfu_signal[vbaid] &= tmpDataRec.sign; //may cause 3rd players to be not recognized
                                                //linkmem.rfu_signal[gbaid] = linkmem.rfu_signal[vbaid];
                                                DATALIST.pop_front();
                                                ok = (IsLinkConnected()/*lanlink.connected*/ && !DATALIST.empty() && DATALIST.front().gbaid==gbaid);
                                                c_s.Unlock();
                                                
                                            } while (ok);
                                        
                                        if (rfu_qrecv>0) { //data was available
                                            rfu_state = RFU_RECV;
                                            rfu_counter = 0;
                                            rfu_lastcmd2 = 0;
                                            if(rfu_qrecv>1) //(rfu_qrecv == 2)
                                                rfu_clientstate[rfu_curclient] = 1;
                                            
                                            //Switch remote id to next remote id
                                            /*if (linkmem.rfu_request[vbaid]) { //is a host
                                             if(rfu_numclients>0) {
                                             rfu_curclient = (rfu_curclient+1) % rfu_numclients;
                                             rfu_id = rfu_clientlist[rfu_curclient];
                                             gbaid = (rfu_id-0x61f1)>>3;
                                             //log("%d  SwitchNext%02X:%d\n",GetTickCount(),rfu_cmd,gbaid);
                                             }
                                             }*/
                                        }
                                        //rfu_transfer_end = 1;
                                        rfu_cmd ^= 0x80;
                                        break;
                                        
                                    case 0x24:	// send [non-important] data (used by server often)
                                        if(rfu_cansend) {
                                            c_s.Lock();
                                            memcpy(linkmem.rfu_data[vbaid],rfu_masterdata,4*rfu_qsend2);
                                            linkmem.rfu_proto[vbaid] = 0; //UDP-like
                                            if(rfu_ishost)
                                                linkmem.rfu_qid[vbaid] = linkmem.rfu_request[vbaid]; else
                                                    linkmem.rfu_qid[vbaid] |= 1<<gbaid;
                                            linkmem.rfu_q[vbaid] = rfu_qsend2;
                                            c_s.Unlock();
                                        } else {
#ifdef GBA_LOGGING
                                            if(systemVerbose & VERBOSE_LINK) {
                                                //log("%08X : IgnoredSend[%02X] %d\n", GetTickCount(), rfu_cmd, rfu_qsend2);
                                            }
#endif
                                        }
                                        //numtransfers++; //not needed, just to keep track
                                        if((numtransfers++)==0) linktime = 1; //needed to synchronize both performance and for Digimon Racing's client to join successfully //numtransfers used to reset linktime to prevent it from reaching beyond max value of integer? //numtransfers doesn't seems to be used?
                                        /*c_s.Lock();
                                         linkmem.rfu_linktime[vbaid] = linktime; //save the ticks before reseted to zero
                                         c_s.Unlock();*/
                                        if(rfu_qsend2>0) {
                                            rfu_masterq = rfu_qsend2; //(sizeof(linkmem.rfu_bdata[vbaid])+3) >> 2; //7 dwords
                                            if(rfu_ishost)
                                                outbuffer[1] = 0x80|vbaid; else //'W'; //destination GBA ID (needed for routing), if dest id = vbaid then it's a broadcast
                                                    outbuffer[1] = 0x80|gbaid;
                                            outbuffer[0] = (rfu_masterq+3)<<2; //total size including headers //vbaid;
                                            outbuffer[2] = rfu_cmd;
                                            outbuffer[3] = rfu_masterq+2;
                                            u32outbuffer[1] = linkmem.rfu_signal[vbaid];
                                            u32outbuffer[2] = linktime;
                                            memcpy(&u32outbuffer[3],rfu_masterdata,(rfu_masterq)<<2); //data size (excluding headers)
                                            LinkSendData(outbuffer, (rfu_masterq+3)<<2, RetryCount, 0); //broadcast
                                            c_s.Lock();
                                            if(rfu_qsend2>1)
                                                linkmem.rfu_state[vbaid] = 1;
                                            linkmem.rfu_qid[vbaid] = 0;
                                            linkmem.rfu_q[vbaid] = 0;
                                            c_s.Unlock();
                                            //log("%08X  CMD24 Sent: %d %d\n",GetTickCount(),rfu_qsend2,linkmem.rfu_q[vbaid]);
                                        }
                                        linktime = 0; //need to zeroed when sending? //0 might cause slowdown in performance
                                        //rfu_transfer_end = 1;
                                        rfu_cmd ^= 0x80;
                                        break;
                                        
                                    case 0x25:	// send [important] data & wait for [important?] reply data
                                    case 0x35:	// send [important] data & wait for [important?] reply data
                                        if(rfu_cansend) {
                                            c_s.Lock();
                                            memcpy(linkmem.rfu_data[vbaid],rfu_masterdata,4*rfu_qsend2);
                                            linkmem.rfu_proto[vbaid] = 1; //TCP-like
                                            if(rfu_ishost)
                                                linkmem.rfu_qid[vbaid] = linkmem.rfu_request[vbaid]; else
                                                    linkmem.rfu_qid[vbaid] |= 1<<gbaid;
                                            linkmem.rfu_q[vbaid] = rfu_qsend2;
                                            c_s.Unlock();
                                        } else {
#ifdef GBA_LOGGING
                                            if(systemVerbose & VERBOSE_LINK) {
                                                //log("%08X : IgnoredSend[%02X] %d\n", GetTickCount(), rfu_cmd, rfu_qsend2);
                                            }
#endif
                                        }
                                        //numtransfers++; //not needed, just to keep track
                                        if ((numtransfers++) == 0) linktime = 1; //0; //might be needed to synchronize both performance? //numtransfers used to reset linktime to prevent it from reaching beyond max value of integer? //seems to be needed? otherwise data can't be received properly? //related to 0x24?
                                        //linktime = 0;
                                        /*c_s.Lock();
                                         linkmem.rfu_linktime[vbaid] = linktime; //save the ticks before changed to synchronize performance
                                         c_s.Unlock();*/
                                        if(rfu_qsend2>0) {
                                            rfu_masterq = rfu_qsend2; //(sizeof(linkmem.rfu_bdata[vbaid])+3) >> 2; //7 dwords
                                            if(rfu_ishost)
                                                outbuffer[1] = 0x80|vbaid; else //'W'; //destination GBA ID (needed for routing), if dest id = vbaid then it's a broadcast
                                                    outbuffer[1] = 0x80|gbaid;
                                            outbuffer[0] = (rfu_masterq+3)<<2; //total size including headers //vbaid;
                                            outbuffer[2] = rfu_cmd;
                                            outbuffer[3] = rfu_masterq+2;
                                            u32outbuffer[1] = linkmem.rfu_signal[vbaid];
                                            u32outbuffer[2] = linktime;
                                            memcpy(&u32outbuffer[3],rfu_masterdata,rfu_masterq<<2); //data size (excluding headers)
                                            LinkSendData(outbuffer, (rfu_masterq+3)<<2, RetryCount, 0); //broadcast
                                            c_s.Lock();
                                            if(rfu_qsend2>1)
                                                linkmem.rfu_state[vbaid] = 1;
                                            linkmem.rfu_qid[vbaid] = 0;
                                            linkmem.rfu_q[vbaid] = 0;
                                            c_s.Unlock();
                                            //log("%08X  CMD25 Sent: %d %d\n",GetTickCount(),rfu_qsend2,linkmem.rfu_q[vbaid]);
                                        }
                                        //rfu_transfer_end = 1;
                                        rfu_cmd ^= 0x80;
                                        break;
                                        
                                    case 0x27:	// wait for data ?
                                    case 0x37:	// wait for data ?
                                        //numtransfers++; //not needed, just to keep track
                                        if ((numtransfers++) == 0) linktime = 1; //0; //might be needed to synchronize both performance? //numtransfers used to reset linktime to prevent it from reaching beyond max value of integer? //seems to be needed? otherwise data can't be received properly? //related to 0x24?
                                        //linktime = 0;
                                        /*c_s.Lock();
                                         linkmem.rfu_linktime[vbaid] = linktime; //save the ticks before changed to synchronize performance
                                         c_s.Unlock();*/
                                        
                                        rfu_masterq = 2;
                                        if(rfu_ishost)
                                            outbuffer[1] = 0x80|vbaid; else //'W'; //destination GBA ID (needed for routing), if dest id = vbaid then it's a broadcast
                                                outbuffer[1] = 0x80|gbaid;
                                        outbuffer[0] = (rfu_masterq+1)<<2; //total size including headers //vbaid;
                                        outbuffer[2] = rfu_cmd;
                                        outbuffer[3] = rfu_masterq;
                                        u32outbuffer[1] = linkmem.rfu_signal[vbaid];
                                        u32outbuffer[2] = linktime;
                                        LinkSendData(outbuffer, (rfu_masterq+1)<<2, RetryCount, 0);
                                        //c_s.Lock();
                                        //linkmem.rfu_state[vbaid] = 1;
                                        //linkmem.rfu_qid[vbaid] = 0;
                                        //linkmem.rfu_q[vbaid] = 0;
                                        //c_s.Unlock();
                                        //rfu_transfer_end = 1;
                                        rfu_cmd ^= 0x80;
                                        break;
                                        
                                    case 0xee: //is this need to be processed?
                                        rfu_cmd ^= 0x80;
                                        rfu_polarity = 1;
                                        break;
                                        
                                    case 0x17:	// setup or something ?
                                    default:
                                        rfu_cmd ^= 0x80;
                                        break;
                                        
                                    case 0xa5:	//	2nd part of send&wait function 0x25
                                    case 0xa7:	//	2nd part of wait function 0x27
                                    case 0xb5:	//	2nd part of send&wait function 0x35?
                                    case 0xb7:	//	2nd part of wait function 0x37?
                                        //bool ok;
                                        c_s.Lock();
                                        ok = !DATALIST.empty();
                                        c_s.Unlock();
                                        if(ok) {
                                            rfu_polarity = 1; //reverse polarity to make the game send 0x80000000 command word (to be replied with 0x99660028 later by the adapter)
                                            if(rfu_cmd==0xa5 || rfu_cmd==0xa7) rfu_cmd = 0x28; else rfu_cmd = 0x36; //there might be 0x29 also //don't return 0x28 yet until there is incoming data (or until 500ms-6sec timeout? may reset RFU after timeout)
                                        } else
                                            rfu_waiting = true;
                                        
                                        c_s.Lock();
                                        rfu_transfer_end = linkmem.rfu_linktime[gbaid] - linktime + 1; //+ 256; //waiting ticks = ticks difference between GBAs send/recv? //is max value of vbaid=1 ?
                                        c_s.Unlock();
                                        
                                        if (rfu_transfer_end > 2560) //may need to cap the max ticks to prevent some games (ie. pokemon) from getting in-game timeout due to executing too many opcodes (too fast)
                                            rfu_transfer_end = 2560;
                                        
                                        if (rfu_transfer_end < 256) //lower/unlimited = faster client but slower host
                                            rfu_transfer_end = 256; //need to be positive for balanced performance in both GBAs?
                                        
                                        linktime = -rfu_transfer_end; //needed to synchronize performance on both side
                                        break;
                                }
                                //UPDATE_REG(COMM_SIODATA32_H, 0x9966);
                                //UPDATE_REG(COMM_SIODATA32_L, (rfu_qrecv<<8) | rfu_cmd);
                                if(!rfu_waiting)
                                    rfu_buf = 0x99660000|(rfu_qrecv<<8) | rfu_cmd; 
                                else rfu_buf = READ32LE(&gGba.mem.ioMem.b[COMM_SIODATA32_L]);
                            }
                        } else { //unknown COMM word //in MarioGolfAdv (when a player/client exiting lobby), There is a possibility COMM = 0x7FFE8001, PrevVAL = 0x5087, PrevCOM = 0, is this part of initialization?
                            //log("%08X : UnkCOM %08X  %04X  %08X %08X\n", GetTickCount(), READ32LE(&gGba.mem.ioMem.b[COMM_SIODATA32_L]), PrevVAL, PrevCOM, PrevDAT);
                            /*rfu_cmd ^= 0x80;
                             UPDATE_REG(COMM_SIODATA32_L, 0);
                             UPDATE_REG(COMM_SIODATA32_H, 0x8000);*/
                            rfu_state = RFU_INIT; //to prevent the next reinit words from getting in finalization processing (here), may cause MarioGolfAdv to show Linking error when this occurs instead of continuing with COMM cmd
                            //UPDATE_REG(COMM_SIODATA32_H, READ16LE(&gGba.mem.ioMem.b[COMM_SIODATA32_L])); //replying with reversed words may cause MarioGolfAdv to reinit RFU when COMM = 0x7FFE8001
                            //UPDATE_REG(COMM_SIODATA32_L, a);
                            rfu_buf = (READ16LE(&gGba.mem.ioMem.b[COMM_SIODATA32_L])<<16)|a;
                        }
                        break;
                        
                    case RFU_SEND: //data following after initialize cmd
                        
                        printf("RFU_SEND\n");
                        
                        //if(rfu_qsend==0) {rfu_state = RFU_COMM; break;}
                        CurDAT = READ32LE(&gGba.mem.ioMem.b[COMM_SIODATA32_L]);
                        if(--rfu_qsend == 0) {
                            rfu_state = RFU_COMM;
                        }
                        
                        switch (rfu_cmd) {
                            case 0x16:
                                //linkmem.rfu_bdata[vbaid][1 + rfu_counter++] = READ32LE(&gGba.mem.ioMem.b[COMM_SIODATA32_L]);
                                rfu_masterdata[1 + rfu_counter++] = READ32LE(&gGba.mem.ioMem.b[COMM_SIODATA32_L]);
                                break;
                                
                            case 0x24:
                                //if(linkmem.rfu_proto[vbaid]) break; //important data from 0x25 shouldn't be overwritten by 0x24
                            case 0x25:
                            case 0x35:
                                //rfu_transfer_end = 1;
                                //if(rfu_cansend) 
                            {
                                //c_s.Lock();
                                //linkmem.rfu_data[vbaid][rfu_counter++] = READ32LE(&gGba.mem.ioMem.b[COMM_SIODATA32_L]);
                                rfu_masterdata[rfu_counter++] = READ32LE(&gGba.mem.ioMem.b[COMM_SIODATA32_L]);
                                //c_s.Unlock();
                            }
                                break;
                                
                            default:
                                rfu_masterdata[rfu_counter++] = READ32LE(&gGba.mem.ioMem.b[COMM_SIODATA32_L]);
                                break;
                        }
                        //UPDATE_REG(COMM_SIODATA32_L, 0);
                        //UPDATE_REG(COMM_SIODATA32_H, 0x8000);
                        rfu_buf = 0x80000000;
                        break;
                        
                    case RFU_RECV: //data following after finalize cmd
                        
                        printf("RFU_RECV\n");
                        
                        //if(rfu_qrecv==0) {rfu_state = RFU_COMM; break;}
                        if (--rfu_qrecv == 0)
                            rfu_state = RFU_COMM;
                        
                        switch (rfu_cmd) {
                            case 0xb6:
                            case 0xa6:
                                //rfu_transfer_end = 1;
                                //UPDATE_REG(COMM_SIODATA32_L, rfu_masterdata[rfu_counter]&0xffff);
                                //UPDATE_REG(COMM_SIODATA32_H, rfu_masterdata[rfu_counter++]>>16);
                                rfu_buf = rfu_masterdata[rfu_counter++];
                                break;
                                
                            case 0x91: //signal strength
                                //rfu_transfer_end = 1;
                                //UPDATE_REG(COMM_SIODATA32_L, rfu_masterdata[rfu_counter]&0xffff);
                                //UPDATE_REG(COMM_SIODATA32_H, rfu_masterdata[rfu_counter++]>>16);
                                rfu_buf = rfu_masterdata[rfu_counter++];
                                break;
                                
                            case 0x93:	//this adapter id?
                            case 0x94:	//disconnected client id?
                            case 0x9a: //client list
                            case 0x9d: //game room list
                            case 0x9e: //game room list
                            case 0xa0: //this client id, index and join status
                            case 0xa1: //this client id and index
                            case 0xb3: //rejoin error code?
                                //UPDATE_REG(COMM_SIODATA32_L, rfu_masterdata[rfu_counter]&0xffff);
                                //UPDATE_REG(COMM_SIODATA32_H, rfu_masterdata[rfu_counter++]>>16);
                                rfu_buf = rfu_masterdata[rfu_counter++];
                                break;
                                
                            default: //unknown data (should use 0 or -1 as default), usually returning 0 might cause the game to think there is something wrong with the connection (ie. 0x11/0x13 cmd)
                                //UPDATE_REG(COMM_SIODATA32_L, 0xffff);  //0x0173 //not 0x0000 as default?
                                //UPDATE_REG(COMM_SIODATA32_H, 0xffff); //0x0000
                                rfu_buf = 0xffffffff; //rfu_masterdata[rfu_counter++];
                                break;
                        }
                        break;
                }
                transfer = 1;
                
                PrevVAL = value;
                PrevDAT = CurDAT;
                PrevCOM = CurCOM;
                
            }
            
            if (rfu_polarity)
                value ^= 4;	// sometimes it's the other way around
            /*value &= 0xfffb;
             value |= (value & 1)<<2;*/
            
#ifdef GBA_LOGGING
            if(systemVerbose & VERBOSE_LINK) {
                if(st != _T(""))
                    //log("%s\n", (LPCTSTR)st);
                logstartd = false;
                st = _T("");
                //st2 = _T(""); //st;
            }
#endif
            
        default: //other SIO modes
            
            printf("Default Socket!\n");
            return value;
    }
}

// StartRFU4
static void StartRFUSocket(u16 value)
{
    if (gGba.mem.ioMem.b == NULL)
        return;
    
    if(value)
        switch (GetSIOMode(value, READ16LE(&gGba.mem.ioMem.b[COMM_RCNT]))) { //
            case MULTIPLAYER:
            case NORMAL8:
            case UART:
                if(gba_link_auto) {
                    rfu_enabled = false;
                    gba_link_enabled = true;
                }
                break;
            case NORMAL32:
                if(gba_link_auto) {
                    rfu_enabled = true;
                    gba_link_enabled = true;
                }
                break;
            default:
                if(gba_link_auto) gba_link_enabled = false;
        }
    
    if (((READ16LE(&gGba.mem.ioMem.b[COMM_SIOCNT]) & 0x5080)==0x1000) && ((value & 0x5080)==0x5080)) { //RFU Reset, may also occur before cable link started
        
        //if(dol) dol->DiscardData(); //Joybus
        
        if(IsLinkConnected()/*lanlink.connected*/) {
            if(rfu_enabled) {
                char outbuf[4];
                outbuf[1] = 0x80|vbaid; //'W'; //destination GBA ID (needed for routing), if dest id = vbaid then it's a broadcast
                outbuf[0] = 4; //total size including headers //vbaid;
                outbuf[2] = 0x3d;
                outbuf[3] = 0;
                LinkSendData(outbuf, 4, RetryCount, 0); //broadcast
            }
            if(vbaid || !rfu_enabled) //shouldn't be discarded by server as it may need to be bridged/redirected
            {
                // GBARemove LinkDiscardData(0);
            }
            
        }
        c_s.Lock();
        DATALIST.clear();
        linkmem.rfu_listfront[vbaid] = 0;
        linkmem.rfu_listback[vbaid] = 0;
        c_s.Unlock();
    }
    
    if (gba_link_enabled && rfu_enabled) {
        if(IsLinkConnected()/*lanlink.connected*/)
        {
            UPDATE_REG(COMM_SIOCNT, PrepareRFUSocket(value)); //Network
        }
        
        
        return;
    } else {
        if ((value & 0x5080)==0x5080) { //0x5083 //game tried to send wireless command but w/o the adapter
            /*if (value & 8) //Transfer Enable Flag Send (bit.3, 1=Disable Transfer/Not Ready)
             value &= 0xfffb; //Transfer enable flag receive (0=Enable Transfer/Ready, bit.2=bit.3 of otherside)	// A kind of acknowledge procedure
             else //(Bit.3, 0=Enable Transfer/Ready)
             value |= 4; //bit.2=1 (otherside is Not Ready)*/
            
            if (READ16LE(&gGba.mem.ioMem.b[COMM_SIOCNT]) & 0x4000) //IRQ Enable
            {
                gGba.mem.ioMem.IF |= 0x80; //Serial Communication
                UPDATE_REG(0x202, gGba.mem.ioMem.IF); //Interrupt Request Flags / IRQ Acknowledge
            }
            value &= 0xff7f; //Start bit.7 reset //may cause the game to retry sending again
            //value |= 0x0008; //SO bit.3 set automatically upon transfer completion
            transfer = 0;
        }
    }
    
    if(!linkid && ls.initd>0) { //may not be needed? //Server, if previous data exchange not done yet don't initiate anymore data exchange
        UPDATE_REG(COMM_SIOCNT, value);
        return;
    }
    
    bool sent = false;
    //u16 prvSIOCNT = READ16LE(&gGba.mem.ioMem.b[COMM_SIOCNT]);
    
    switch (GetSIOMode(value, READ16LE(&gGba.mem.ioMem.b[COMM_RCNT]))) {
        case MULTIPLAYER:
            if (value & 0x80) { //AdamN: Start.Bit=Start/Active (transfer initiated)
                if (!linkid) { //is master/server?
                    if (!transfer) { //not in the middle of transfering previous data?
                        if (IsLinkConnected()/*lanlink.connected*/)
                        {
                            linkdata[0] = READ16LE(&gGba.mem.ioMem.b[COMM_SIODATA8]); //AdamN: SIOMLT_SEND(16bit data to be sent) on MultiPlayer mode
                            savedlinktime = linktime;
                            tspeed = value & 3;
                            //LogStrPush("StartLink1");
                            sent = true;
                            ls.Send(); //AdamN: Server need to send this often, initiate data exchange
                            //LogStrPop(10);
                            if(sent) {
                                transfer = 1;
                                linktime = 0;
                                UPDATE_REG(COMM_SIODATA32_L, linkdata[0]); //AdamN: SIOMULTI0 (16bit data received from master/server)
                                UPDATE_REG(COMM_SIODATA32_H, 0xffff); //AdamN: SIOMULTI1 (16bit data received from slave1, reset to FFFFh upon transfer start)
                                WRITE32LE(&gGba.mem.ioMem.b[0x124], 0xffffffff); //AdamN: data from SIOMULTI2 & SIOMULTI3
                                if (lanlink.speed && oncewait == false) //lanlink.speed = speedhack
                                    ls.howmanytimes++;
                                after = false;
                            }
                        }
                    }
                }
                /*if(sent) { //Is this needed? Disabling Start.bit.7 should be done by IRQ handler isn't?
                 value &= 0xff7f;
                 value |= (transfer != 0) << 7;
                 }*/
            }
            /*if(sent)*/ { //AdamN: no need to check for sent here
                value &= 0xff8b;
                value |= (linkid ? 0xc : 8);
                value |= linkid << 4;
                
                //AdamN: doesn't seems to be needed
                if (linkid)
                    UPDATE_REG(COMM_RCNT, 7);
                else
                    UPDATE_REG(COMM_RCNT, 3);
            }
            UPDATE_REG(COMM_SIOCNT, value);
            if(sent || (linkid && (value & 0x3f)==0x0f))
                LinkUpdate(0);
            break;
            
        case NORMAL8: //used for GB/GBC
        case NORMAL32: //used for RFU
        case UART:
        default:
            UPDATE_REG(COMM_SIOCNT, value);
            break;
    }
    
    
}

static void StartCableIPC(u16 value)
{
	switch (GetSIOMode(value, READ16LE(&gGba.mem.ioMem.b[COMM_RCNT]))) {
        case MULTIPLAYER: {
            bool start = (value & 0x80) && !linkid && !transfer;
            // clear start, seqno, si (RO on slave, start = pulse on master)
            value &= 0xff4b;
            // get current si.  This way, on slaves, it is low during xfer
            if(linkid) {
                if(!transfer)
                    value |= 4;
                else
                    value |= READ16LE(&gGba.mem.ioMem.b[COMM_SIOCNT]) & 4;
            }
            if (start) {
                if (linkmem.numgbas > 1)
                {
                    // find first active attached GBA
                    // doing this first reduces the potential
                    // race window size for new connections
                    int n = linkmem.numgbas + 1;
                    int f = linkmem.linkflags;
                    int m;
                    do {
                        n--;
                        m = (1 << n) - 1;
                    } while((f & m) != m);
                    linkmem.trgbas = n;
                    
                    // before starting xfer, make pathetic attempt
                    // at clearing out any previous stuck xfer
                    // this will fail if a slave was stuck for
                    // too long
                    for(int i = 0; i < 4; i++)
                        while(WaitForSingleObject(linksync[i], 0) != WAIT_TIMEOUT);
                    
                    // transmit first value
                    linkmem.linkcmd = ('M' << 8) + (value & 3);
                    linkmem.linkdata[0] = READ16LE(&gGba.mem.ioMem.b[COMM_SIODATA8]);
                    
                    // start up slaves & sync clocks
                    numtransfers = linkmem.numtransfers;
                    if (numtransfers != 0)
                        linkmem.lastlinktime = linktime;
                    else
                        linkmem.lastlinktime = 0;
                    
                    if ((++numtransfers) == 0)
                        linkmem.numtransfers = 2;
                    else
                        linkmem.numtransfers = numtransfers;
                    
                    transfer = 1;
                    linktime = 0;
                    tspeed = value & 3;
                    WRITE32LE(&gGba.mem.ioMem.b[COMM_SIOMULTI0], 0xffffffff);
                    WRITE32LE(&gGba.mem.ioMem.b[COMM_SIOMULTI2], 0xffffffff);
                    value &= ~0x40;
                } else {
                    value |= 0x40; // comm error
                }
            }
            value |= (transfer != 0) << 7;
            value |= (linkid && !transfer ? 0xc : 8); // set SD (high), SI (low on master)
            value |= linkid << 4; // set seq
            UPDATE_REG(COMM_SIOCNT, value);
            if (linkid)
                // SC low -> transfer in progress
                // not sure why SO is low
                UPDATE_REG(COMM_RCNT, transfer ? 6 : 7);
            else
                // SI is always low on master
                // SO, SC always low during transfer
                // not sure why SO low otherwise
                UPDATE_REG(COMM_RCNT, transfer ? 2 : 3);
            break;
        }
        case NORMAL8:
        case NORMAL32:
        case UART:
        default:
            UPDATE_REG(COMM_SIOCNT, value);
            break;
	}
}

void StartCableSocket(u16 value)
{
	switch (GetSIOMode(value, READ16LE(&gGba.mem.ioMem.b[COMM_RCNT]))) {
        case MULTIPLAYER: {
            bool start = (value & 0x80) && !linkid && !transfer;
            // clear start, seqno, si (RO on slave, start = pulse on master)
            value &= 0xff4b;
            // get current si.  This way, on slaves, it is low during xfer
            if(linkid) {
                if(!transfer)
                    value |= 4;
                else
                    value |= READ16LE(&gGba.mem.ioMem.b[COMM_SIOCNT]) & 4;
            }
            if (start) {
                linkdata[0] = READ16LE(&gGba.mem.ioMem.b[COMM_SIODATA8]);
                savedlinktime = linktime;
                tspeed = value & 3;
                ls.Send();
                transfer = 1;
                linktime = 0;
                UPDATE_REG(COMM_SIOMULTI0, linkdata[0]);
                UPDATE_REG(COMM_SIOMULTI1, 0xffff);
                WRITE32LE(&gGba.mem.ioMem.b[COMM_SIOMULTI2], 0xffffffff);
                if (lanlink.speed && oncewait == false)
                    ls.howmanytimes++;
                after = false;
                value &= ~0x40;
            }
            value |= (transfer != 0) << 7;
            value |= (linkid && !transfer ? 0xc : 8); // set SD (high), SI (low on master)
            value |= linkid << 4; // set seq
            UPDATE_REG(COMM_SIOCNT, value);
            if (linkid)
                // SC low -> transfer in progress
                // not sure why SO is low
                UPDATE_REG(COMM_RCNT, transfer ? 6 : 7);
            else
                // SI is always low on master
                // SO, SC always low during transfer
                // not sure why SO low otherwise
                UPDATE_REG(COMM_RCNT, transfer ? 2 : 3);
            break;
        }
        case NORMAL8:
        case NORMAL32:
        case UART:
        default:
            UPDATE_REG(COMM_SIOCNT, value);
            break;
	}
}

void StartLink(u16 siocnt)
{
	if (!linkDriver || !linkDriver->start) {
		return;
	}
    
	linkDriver->start(siocnt);
}

void StartGPLink(u16 value)
{
    u16 oldval = READ16LE(&gGba.mem.ioMem.b[COMM_RCNT]);
    
	UPDATE_REG(COMM_RCNT, value);
    
    
    u16 siocnt = READ16LE(&gGba.mem.ioMem.b[COMM_SIOCNT]);
    //if(siocnt || value)
    switch (GetSIOMode(siocnt, value)) { //
        case MULTIPLAYER:
        case NORMAL8:
        case UART:
            if(gba_link_auto) {
                rfu_enabled = false;
                gba_link_enabled = true;
            }
            break;
        case NORMAL32:
            if(gba_link_auto) {
                rfu_enabled = true;
                gba_link_enabled = true;
            }
            break;
        default:
            if(gba_link_auto) gba_link_enabled = false;
    }
    
    c_s.Lock();
    if((READ16LE(&gGba.mem.ioMem.b[RF_RECVCMD]) & 0xff)==0)
        UPDATE_REG(RF_RECVCMD, 0x3d); //value should be >=0x20 or 0x0..0x11 or 0x0..0x1f ? is this RFU cmd?
    c_s.Unlock();
    
    
	if (!value)
		return;
    
	switch (GetSIOMode(READ16LE(&gGba.mem.ioMem.b[COMM_SIOCNT]), value)) {
        case MULTIPLAYER:
            value &= 0xc0f0;
            value |= 3;
            if (linkid)
                value |= 4;
            UPDATE_REG(COMM_SIOCNT, ((READ16LE(&gGba.mem.ioMem.b[COMM_SIOCNT])&0xff8b)|(linkid ? 0xc : 8)|(linkid<<4)));
            break;
            
        case GP:
            if (GetLinkMode() == LINK_RFU_IPC || GetLinkMode() == LINK_RFU_SOCKET)
            {
                /*if ((rfu_lastcmd|0x80)!=0 && ((rfu_lastcmd|0x80)>=0x9b && (rfu_lastcmd|0x80)<=0xa1))
                 log("RST %02X, %02X, %02X, %02X\n",rfu_cmd, rfu_lastcmd, rfu_lastcmd2, rfu_lastcmd3);*/
                rfu_state = RFU_INIT; //reset wireless
                rfu_polarity = 0;
                rfu_initialized = false;
                //WaitForSingleObject(linksync[vbaid], linktimeout);
                c_s.Lock();
                //ResetEvent(linksync[vbaid]);
                if(vbaid!=gbaid) { //(linkmem->numgbas >= 2)
                    //linkmem->rfu_signal[gbaid] = 0;
                    linkmem.rfu_request[gbaid] &= ~(1<<vbaid); //linkmem->rfu_request[gbaid] = 0; //needed to detect MarioGolfAdv client exiting lobby
                    SetEvent(linksync[gbaid]); //allow other gba to move
                }
                linkmem.rfu_signal[vbaid] = 0;
                linkmem.rfu_request[vbaid] = 0;
                //linkmem->rfu_q[vbaid] = 0; //need to give a chance for other side to receive the last data before exiting multiplayer game
                linkmem.rfu_proto[vbaid] = 0;
                linkmem.rfu_qid[vbaid] = 0;
                linkmem.rfu_reqid[vbaid] = 0;
                linkmem.rfu_linktime[vbaid] = 0;
                linkmem.rfu_latency[vbaid] = -1;
                linkmem.rfu_bdata[vbaid][0] = 0;
                SetEvent(linksync[vbaid]);
                c_s.Unlock();
                numtransfers = 0;
                rfu_masterq = 0;
                rfu_id = 0;
                gbaid = vbaid;
                gbaidx = gbaid;
                rfu_idx = 0;
                rfu_lastcmd = 0;
                rfu_lastcmd2 = 0;
                rfu_lastcmd3 = 0;
                rfu_ishost = false;
                rfu_isfirst = false;
                //rfu_waiting = false;
            }
            
            break;
	}
}

static ConnectionState JoyBusConnect()
{
	delete dol;
	dol = NULL;
    
	dol = new GBASockClient();
	bool connected = dol->Connect(joybusHostAddr);
    
	if (connected) {
		return LINK_OK;
	} else {
		systemMessage(0, N_("Error, could not connect to Dolphin"));
		return LINK_ERROR;
	}
}

static void JoyBusShutdown()
{
	delete dol;
	dol = NULL;
}

static void JoyBusUpdate(int ticks)
{
	static int lastjoybusupdate = 0;
    
	// Kinda ugly hack to update joybus stuff intermittently
	if (linktime > lastjoybusupdate + 0x3000)
	{
		lastjoybusupdate = linktime;
        
		char data[5] = {0x10, 0, 0, 0, 0}; // init with invalid cmd
		std::vector<char> resp;
        
		if (!dol)
			JoyBusConnect();
        
		u8 cmd = dol->ReceiveCmd(data);
		switch (cmd) {
            case JOY_CMD_RESET:
                UPDATE_REG(COMM_JOYCNT, READ16LE(&gGba.mem.ioMem.b[COMM_JOYCNT]) | JOYCNT_RESET);
                
            case JOY_CMD_STATUS:
                resp.push_back(0x00); // GBA device ID
                resp.push_back(0x04);
                break;
                
            case JOY_CMD_READ:
                resp.push_back((u8)(READ16LE(&gGba.mem.ioMem.b[COMM_JOY_TRANS_L]) & 0xff));
                resp.push_back((u8)(READ16LE(&gGba.mem.ioMem.b[COMM_JOY_TRANS_L]) >> 8));
                resp.push_back((u8)(READ16LE(&gGba.mem.ioMem.b[COMM_JOY_TRANS_H]) & 0xff));
                resp.push_back((u8)(READ16LE(&gGba.mem.ioMem.b[COMM_JOY_TRANS_H]) >> 8));
                UPDATE_REG(COMM_JOYSTAT, READ16LE(&gGba.mem.ioMem.b[COMM_JOYSTAT]) & ~JOYSTAT_SEND);
                UPDATE_REG(COMM_JOYCNT, READ16LE(&gGba.mem.ioMem.b[COMM_JOYCNT]) | JOYCNT_SEND_COMPLETE);
                break;
                
            case JOY_CMD_WRITE:
                UPDATE_REG(COMM_JOY_RECV_L, (u16)((u16)data[2] << 8) | (u8)data[1]);
                UPDATE_REG(COMM_JOY_RECV_H, (u16)((u16)data[4] << 8) | (u8)data[3]);
                UPDATE_REG(COMM_JOYSTAT, READ16LE(&gGba.mem.ioMem.b[COMM_JOYSTAT]) | JOYSTAT_RECV);
                UPDATE_REG(COMM_JOYCNT, READ16LE(&gGba.mem.ioMem.b[COMM_JOYCNT]) | JOYCNT_RECV_COMPLETE);
                break;
                
            default:
                return; // ignore
		}
        
		resp.push_back((u8)READ16LE(&gGba.mem.ioMem.b[COMM_JOYSTAT]));
		dol->Send(resp);
        
		// Generate SIO interrupt if we can
		if ( ((cmd == JOY_CMD_RESET) || (cmd == JOY_CMD_READ) || (cmd == JOY_CMD_WRITE))
			&& (READ16LE(&gGba.mem.ioMem.b[COMM_JOYCNT]) & JOYCNT_INT_ENABLE) )
		{
			gGba.mem.ioMem.IF |= 0x80;
			UPDATE_REG(0x202, gGba.mem.ioMem.IF);
		}
	}
}

static void ReInitLink();

static void UpdateCableIPC(int ticks)
{
	// slave startup depends on detecting change in numtransfers
	// and syncing clock with master (after first transfer)
	// this will fail if > ~2 minutes have passed since last transfer due
	// to integer overflow
	if(!transfer && numtransfers && linktime < 0) {
		linktime = 0;
		// there is a very, very, small chance that this will abort
		// a transfer that was just started
		linkmem.numtransfers = numtransfers = 0;
	}
	if (linkid && !transfer && linktime >= linkmem.lastlinktime &&
	    linkmem.numtransfers != numtransfers)
	{
		numtransfers = linkmem.numtransfers;
		if(!numtransfers)
			return;
        
		// if this or any previous machine was dropped, no transfer
		// can take place
		if(linkmem.trgbas <= linkid) {
			transfer = 0;
			numtransfers = 0;
			// if this is the one that was dropped, reconnect
			if(!(linkmem.linkflags & (1 << linkid)))
				ReInitLink();
			return;
		}
        
		// sync clock
		if (numtransfers == 1)
			linktime = 0;
		else
			linktime -= linkmem.lastlinktime;
        
		// there's really no point to this switch; 'M' is the only
		// possible command.
#if 0
		switch ((linkmem.linkcmd) >> 8)
		{
            case 'M':
#endif
                tspeed = linkmem.linkcmd & 3;
                transfer = 1;
                WRITE32LE(&gGba.mem.ioMem.b[COMM_SIOMULTI0], 0xffffffff);
                WRITE32LE(&gGba.mem.ioMem.b[COMM_SIOMULTI2], 0xffffffff);
                UPDATE_REG(COMM_SIOCNT, READ16LE(&gGba.mem.ioMem.b[COMM_SIOCNT]) & ~0x40 | 0x80);
#if 0
                break;
		}
#endif
	}
    
	if (!transfer)
		return;
    
	if (transfer <= linkmem.trgbas && linktime >= trtimedata[transfer-1][tspeed])
	{
		// transfer #n -> wait for value n - 1
		if(transfer > 1 && linkid != transfer - 1) {
			if(WaitForSingleObject(linksync[transfer - 1], linktimeout) == WAIT_TIMEOUT) {
				// assume slave has dropped off if timed out
				if(!linkid) {
					linkmem.trgbas = transfer - 1;
					int f = linkmem.linkflags;
					f &= ~(1 << (transfer - 1));
					linkmem.linkflags = f;
					if(f < (1 << transfer) - 1)
						linkmem.numgbas = transfer - 1;
					char message[30];
					sprintf(message, _("Player %d disconnected."), transfer - 1);
					systemScreenMessage(message);
				}
				transfer = linkmem.trgbas + 1;
				// next cycle, transfer will finish up
				return;
			}
		}
		// now that value is available, store it
		UPDATE_REG((COMM_SIOMULTI0 - 2) + (transfer<<1), linkmem.linkdata[transfer-1]);
        
		// transfer machine's value at start of its transfer cycle
		if(linkid == transfer) {
			// skip if dropped
			if(linkmem.trgbas <= linkid) {
				transfer = 0;
				numtransfers = 0;
				// if this is the one that was dropped, reconnect
				if(!(linkmem.linkflags & (1 << linkid)))
					ReInitLink();
				return;
			}
			// SI becomes low
			UPDATE_REG(COMM_SIOCNT, READ16LE(&gGba.mem.ioMem.b[COMM_SIOCNT]) & ~4);
			UPDATE_REG(COMM_RCNT, 10);
			linkmem.linkdata[linkid] = READ16LE(&gGba.mem.ioMem.b[COMM_SIODATA8]);
			ReleaseSemaphore(linksync[linkid], linkmem.numgbas-1, NULL);
		}
		if(linkid == transfer - 1) {
			// SO becomes low to begin next trasnfer
			// may need to set DDR as well
			UPDATE_REG(COMM_RCNT, 0x22);
		}
        
		// next cycle
		transfer++;
	}
    
	if (transfer > linkmem.trgbas && linktime >= trtimeend[transfer-3][tspeed])
	{
		// wait for slaves to finish
		// this keeps unfinished slaves from screwing up last xfer
		// not strictly necessary; may just slow things down
		if(!linkid) {
			for(int i = 2; i < transfer; i++)
				if(WaitForSingleObject(linksync[0], linktimeout) == WAIT_TIMEOUT) {
					// impossible to determine which slave died
					// so leave them alone for now
					systemScreenMessage(_("Unknown slave timed out; resetting comm"));
					linkmem.numtransfers = numtransfers = 0;
					break;
				}
		} else if(linkmem.trgbas > linkid)
			// signal master that this slave is finished
			ReleaseSemaphore(linksync[0], 1, NULL);
		linktime -= trtimeend[transfer - 3][tspeed];
		transfer = 0;
		u16 value = READ16LE(&gGba.mem.ioMem.b[COMM_SIOCNT]);
		if(!linkid)
			value |= 4; // SI becomes high on slaves after xfer
		UPDATE_REG(COMM_SIOCNT, (value & 0xff0f) | (linkid << 4));
		// SC/SI high after transfer
		UPDATE_REG(COMM_RCNT, linkid ? 15 : 11);
		if (value & 0x4000)
		{
			gGba.mem.ioMem.IF |= 0x80;
			UPDATE_REG(0x202, gGba.mem.ioMem.IF);
		}
	}
}

static void UpdateRFUIPC(int ticks)
{
	rfu_transfer_end -= ticks;
    
	if (transfer && rfu_transfer_end <= 0)
	{
		transfer = 0;
		if (READ16LE(&gGba.mem.ioMem.b[COMM_SIOCNT]) & 0x4000)
		{
			gGba.mem.ioMem.IF |= 0x80;
			UPDATE_REG(0x202, gGba.mem.ioMem.IF);
		}
		UPDATE_REG(COMM_SIOCNT, READ16LE(&gGba.mem.ioMem.b[COMM_SIOCNT]) & 0xff7f);
	}
}

static bool PerformUpdateRFUSocket()
{
    //Network
    if(IsLinkConnected()/*lanlink.connected*/) { //synchronize RFU buffers as necessary to reduce network traffic? (update buffer with incoming data, send new data to other GBAs)
        
    }
    
    if (transfer && rfu_transfer_end <= 0) //this is to prevent continuosly sending & receiving data too fast which will cause the game unable to update the screen (the screen will looks freezed) due to miscommunication
    {
        if (rfu_waiting) {
            bool ok = false;
            u8 oldcmd = rfu_cmd;
            u8 oldq = linkmem.rfu_q[vbaid]; //linkmem->rfu_qlist[vbaid][linkmem->rfu_listfront[vbaid]]; //
            u32 tmout = linktimeout;
            //if(READ16LE(&ioMem[COMM_SIOCNT]) & 0x80) //needed? is this the cause of error when trying to battle for the 2nd time in union room(siocnt = 5003 instead of 5086 when waiting for 0x28 from 0xa5)? OR was it due to left over data?
            if(rfu_state!=RFU_INIT) //not needed?
                if(rfu_cmd == 0x24 || rfu_cmd == 0x25 || rfu_cmd == 0x35) {
                    c_s.Lock();
                    ok = /*gbaid!=vbaid* &&*/ linkmem.rfu_signal[vbaid] && linkmem.rfu_q[vbaid]>1 && rfu_qsend>1 /*&& linkmem->rfu_q[vbaid]>rfu_qsend*/;
                    c_s.Unlock();
                    if(ok && (GetTickCount()-rfu_lasttime)</*1000*/(unsigned long)linktimeout) {/*rfu_transfer_end = 256;*/ return false;}
                    if(linkmem.rfu_q[vbaid]<2 || rfu_qsend>1 /*|| linkmem->rfu_q[vbaid]<=rfu_qsend*/)
                    {
                        rfu_cansend = true;
                        c_s.Lock();
                        linkmem.rfu_q[vbaid] = 0; //rfu_qsend;
                        linkmem.rfu_qid[vbaid] = 0; //
                        c_s.Unlock();
                    }
                    rfu_buf = 0x80000000;
                } else {
                    if(((rfu_cmd == 0x11 || rfu_cmd==0x1a || rfu_cmd==0x26) && (GetTickCount()-rfu_lasttime)<16) || ((rfu_cmd==0xa5 || rfu_cmd==0xb5) && (GetTickCount()-rfu_lasttime)<tmout) || ((rfu_cmd==0xa7 || rfu_cmd==0xb7 /*|| (rfu_lastcmd2==0x24 && rfu_cmd==0x26)*/) && (GetTickCount()-rfu_lasttime)</*1000*/(unsigned long)linktimeout)) { //
                        //ok = false;
                        //if (linkmem->rfu_q[vbaid]<2 /*|| (linkmem->rfu_request[vbaid] && linkmem->rfu_qid[vbaid]!=linkmem->rfu_request[vbaid])*/) //make sure previously sent data have been received
                        c_s.Lock();
                        ok = (!DATALIST.empty() || (linkmem.rfu_listfront[vbaid]!=linkmem.rfu_listback[vbaid]));
                        c_s.Unlock();
                        if(!ok)
                            for(int i=0; i<linkmem.numgbas; i++)
                                if (i!=vbaid)
                                    if (linkmem.rfu_q[i] && (linkmem.rfu_qid[i]&(1<<vbaid))) {ok = true; break;} //wait for reply
                        if(/*vbaid==gbaid ||*/ !linkmem.rfu_signal[vbaid]) ok = true;
                        if(!ok) {/*rfu_transfer_end = 256;*/ return false;}
                    }
                    if(rfu_cmd==0xa5 || rfu_cmd==0xa7 || rfu_cmd==0xb5 || rfu_cmd==0xb7 || rfu_cmd==0xee) rfu_polarity = 1;
                    //rfu_polarity = 1; //reverse polarity to make the game send 0x80000000 command word (to be replied with 0x99660028 later by the adapter)
                    if(rfu_cmd==0xa5 || rfu_cmd==0xa7) rfu_cmd = 0x28; else
                        if(rfu_cmd==0xb5 || rfu_cmd==0xb7) rfu_cmd = 0x36;
                    if(READ32LE(&gGba.mem.ioMem.b[COMM_SIODATA32_L])==0x80000000) rfu_buf = 0x99660000|(rfu_qrecv<<8)|rfu_cmd; else rfu_buf = 0x80000000;
                }
            
            /*UPDATE_REG(COMM_SIODATA32_L, rfu_buf);
             UPDATE_REG(COMM_SIODATA32_H, rfu_buf>>16);*/
            
            rfu_waiting = false;
        }
        
        UPDATE_REG(COMM_SIODATA32_L, rfu_buf);
        UPDATE_REG(COMM_SIODATA32_H, rfu_buf>>16);
        
        /*transfer = 0;
         u16 value = READ16LE(&ioMem[COMM_SIOCNT]);
         if (value & 0x4000) //IRQ Enable
         {
         IF |= 0x80; //Serial Communication
         UPDATE_REG(0x202, IF); //Interrupt Request Flags / IRQ Acknowledge
         }
         
         //if (rfu_polarity) value ^= 4;
         value &= 0xfffb;
         value |= (value & 1)<<2;
         
         UPDATE_REG(COMM_SIOCNT, (value & 0xff7f)|0x0008); //Start bit.7 reset, SO bit.3 set automatically upon transfer completion?
         #ifdef GBA_LOGGING
         if(systemVerbose & VERBOSE_SIO) {
         log("SIOn32 : %04X %04X  %08X  (VCOUNT = %d) %d %d\n", READ16LE(&ioMem[COMM_RCNT]), READ16LE(&ioMem[COMM_SIOCNT]), READ32LE(&ioMem[COMM_SIODATA32_L]), VCOUNT, GetTickCount(), linktime2 );
         }
         #endif*/
    }
    
    return true;
}

static void UpdateRFUSocket(int ticks)
{
        
    linktime2 += ticks; // linktime2 is unused!
    rfu_transfer_end -= ticks;
    
    //if(lanlink.active && lanlink.connected)
    if(PerformUpdateRFUSocket())
    {
        if (transfer && rfu_transfer_end <= 0) //this is to prevent continuosly sending & receiving data too fast which will cause the game unable to update the screen (the screen will looks freezed) due to miscommunication
        {            
            transfer = 0;
            u16 value = READ16LE(&gGba.mem.ioMem.b[COMM_SIOCNT]);
            if (value & 0x4000) //IRQ Enable
            {
                gGba.mem.ioMem.IF |= 0x80; //Serial Communication
                UPDATE_REG(0x202, gGba.mem.ioMem.IF); //Interrupt Request Flags / IRQ Acknowledge
            }
            
            //if (rfu_polarity) value ^= 4;
            value &= 0xfffb;
            value |= (value & 1)<<2; //this will automatically set the correct polarity, even w/o rfu_polarity since the game will be the one who change the polarity instead of the adapter
            
            UPDATE_REG(COMM_SIOCNT, (value & 0xff7f)|0x0008); //Start bit.7 reset, SO bit.3 set automatically upon transfer completion?
        }
    }
    else
    {
        printf("Failture :( !\n");
    }
    return;
}

static void UpdateCableSocket(int ticks)
{
	if (after)
	{
		if (linkid && linktime > 6044) {
            lc.Recv();
			oncewait = true;
		}
		else
			return;
	}
    
	if (linkid && !transfer && lc.numtransfers > 0 && linktime >= savedlinktime)
	{
		linkdata[linkid] = READ16LE(&gGba.mem.ioMem.b[COMM_SIODATA8]);
        
		lc.Send();
        
		UPDATE_REG(COMM_SIODATA32_L, linkdata[0]);
		UPDATE_REG(COMM_SIOCNT, READ16LE(&gGba.mem.ioMem.b[COMM_SIOCNT]) | 0x80);
		transfer = 1;
		if (lc.numtransfers==1)
			linktime = 0;
		else
			linktime -= savedlinktime;
	}
    
	if (transfer && linktime >= trtimeend[lanlink.numslaves-1][tspeed])
	{
		if (READ16LE(&gGba.mem.ioMem.b[COMM_SIOCNT]) & 0x4000)
		{
			gGba.mem.ioMem.IF |= 0x80;
			UPDATE_REG(0x202, gGba.mem.ioMem.IF);
		}
        
		UPDATE_REG(COMM_SIOCNT, (READ16LE(&gGba.mem.ioMem.b[COMM_SIOCNT]) & 0xff0f) | (linkid << 4));
		transfer = 0;
		linktime -= trtimeend[lanlink.numslaves-1][tspeed];
		oncewait = false;
        
		if (!lanlink.speed)
		{
			if (linkid)
				lc.Recv();
			else
				ls.Recv(); // WTF is the point of this?
            
			UPDATE_REG(COMM_SIOMULTI1, linkdata[1]);
			UPDATE_REG(COMM_SIOMULTI2, linkdata[2]);
			UPDATE_REG(COMM_SIOMULTI3, linkdata[3]);
			oncewait = true;
            
		} else {
            
			after = true;
			if (lanlink.numslaves == 1)
			{
				UPDATE_REG(COMM_SIOMULTI1, linkdata[1]);
				UPDATE_REG(COMM_SIOMULTI2, linkdata[2]);
				UPDATE_REG(COMM_SIOMULTI3, linkdata[3]);
			}
		}
	}
}


void LinkUpdate(int ticks)
{
	if (!linkDriver) {
		return;
	}
    
	// this actually gets called every single instruction, so keep default
	// path as short as possible
    
	linktime += ticks;
    
	linkDriver->update(ticks);
}

inline static int GetSIOMode(u16 siocnt, u16 rcnt)
{
	if (!(rcnt & 0x8000))
	{
		switch (siocnt & 0x3000) {
            case 0x0000: return NORMAL8;
            case 0x1000: return NORMAL32;
            case 0x2000: return MULTIPLAYER;
            case 0x3000: return UART;
		}
	}
    
	if (rcnt & 0x4000)
		return JOYBUS;
    
	return GP;
}

static ConnectionState InitIPC() {
	linkid = 0;

    vbaid = 0;
    
    /*
	if((mmf = shm_open("/" LOCAL_LINK_NAME, O_RDWR|O_CREAT|O_EXCL, 0777)) < 0) {
		vbaid = 1;
		mmf = shm_open("/" LOCAL_LINK_NAME, O_RDWR, 0);
	} else
		vbaid = 0;
     
     */
     
	/*if(mmf < 0 || ftruncate(mmf, sizeof(LINKDATA)) < 0 ||
	   !(linkmem = (LINKDATA *)mmap(NULL, sizeof(LINKDATA),
                                    PROT_READ|PROT_WRITE, MAP_SHARED,
                                    mmf, 0))) {
		systemMessage(0, N_("Error creating file mapping"));
		if(mmf) {
			if(!vbaid)
				shm_unlink("/" LOCAL_LINK_NAME);
			close(mmf);
		}
	}*/
    
	// get lowest-numbered available machine slot
	bool firstone = !vbaid;
	if(firstone) {
		linkmem.linkflags = 1;
		linkmem.numgbas = 1;
		linkmem.numtransfers=0;
		for(i=0;i<4;i++)
			linkmem.linkdata[i] = 0xffff;
	} else {
		// FIXME: this should be done while linkmem is locked
		// (no xfer in progress, no other vba trying to connect)
		int n = linkmem.numgbas;
		int f = linkmem.linkflags;
		for(int i = 0; i <= n; i++)
			if(!(f & (1 << i))) {
				vbaid = i;
				break;
			}
		if(vbaid == 4){

			// GBARemove munmap(linkmem, sizeof(LINKDATA));
			if(!vbaid)
				shm_unlink("/" LOCAL_LINK_NAME);
			close(mmf);
			systemMessage(0, N_("5 or more GBAs not supported."));
			return LINK_ERROR;
		}
		if(vbaid == n)
			linkmem.numgbas = n + 1;
		linkmem.linkflags = f | (1 << vbaid);
	}
	linkid = vbaid;
    
	for(i=0;i<4;i++){
		linkevent[sizeof(linkevent)-2]=(char)i+'1';

		/* GBARemove if((linksync[i] = sem_open(linkevent,
                                   firstone ? O_CREAT|O_EXCL : 0,
                                   0777, 0)) == SEM_FAILED) {
			if(firstone)
				shm_unlink("/" LOCAL_LINK_NAME);
			// GBARemove munmap(linkmem, sizeof(LINKDATA));
			close(mmf);
			for(j=0;j<i;j++){
				sem_close(linksync[i]);
				if(firstone) {
					linkevent[sizeof(linkevent)-2]=(char)i+'1';
					sem_unlink(linkevent);
				}
			}
			systemMessage(0, N_("Error opening event"));
			return LINK_ERROR;
		} */
	}
    
	return LINK_OK;
}

static ConnectionState InitSocket() {
	linkid = 0;
    
	for(int i = 0; i < 4; i++)
		linkdata[i] = 0xffff;
    
	if (lanlink.server) {
		lanlink.connectedSlaves = 0;
		// should probably use GetPublicAddress()
		//sid->ShowServerIP(sf::IPAddress::GetLocalAddress());
        
		// too bad Listen() doesn't take an address as well
		// then again, old code used INADDR_ANY anyway
		if (!lanlink.tcpsocket.Listen(IP_LINK_PORT))
			// Note: old code closed socket & retried once on bind failure
			return LINK_ERROR; // FIXME: error code?
		else
			return LINK_NEEDS_UPDATE;
	} else {
		lc.serverport = IP_LINK_PORT;
        
		if (!lc.serveraddr.IsValid()) {
			return  LINK_ERROR;
		} else {
			lanlink.tcpsocket.SetBlocking(false);
			sf::Socket::Status status = lanlink.tcpsocket.Connect(lc.serverport, lc.serveraddr);
            
			if (status == sf::Socket::Error || status == sf::Socket::Disconnected)
				return  LINK_ERROR;
			else
				return  LINK_NEEDS_UPDATE;
		}
	}
}

//////////////////////////////////////////////////////////////////////////
// Probably from here down needs to be replaced with SFML goodness :)
// tjm: what SFML goodness?  SFML for network, yes, but not for IPC

ConnectionState InitLink(LinkMode mode)
{
	// Do nothing if we are already connected
	if (GetLinkMode() != LINK_DISCONNECTED) {
		systemMessage(0, N_("Error, link already connected"));
		return LINK_ERROR;
	}
    
	// Find the link driver
	linkDriver = NULL;
	for (u8 i = 0; i < sizeof(linkDrivers) / sizeof(linkDrivers[0]); i++) {
		if (linkDrivers[i].mode == mode) {
			linkDriver = &linkDrivers[i];
			break;
		}
	}
    
	if (linkDriver == NULL) {
		systemMessage(0, N_("Unable to find link driver"));
		return LINK_ERROR;
	}
    
	// Connect the link
	gba_connection_state = linkDriver->connect();
    
	if (gba_connection_state == LINK_ERROR) {
		CloseLink();
	}
    
	return gba_connection_state;
}

static ConnectionState ConnectUpdateSocket(char * const message, size_t size) {
	ConnectionState newState = LINK_NEEDS_UPDATE;
    
	if (lanlink.server) {
		sf::Selector<sf::SocketTCP> fdset;
		fdset.Add(lanlink.tcpsocket);
        
		if (fdset.Wait(0.1) == 1) {
			int nextSlave = lanlink.connectedSlaves + 1;
            
			sf::Socket::Status st = lanlink.tcpsocket.Accept(ls.tcpsocket[nextSlave]);
            
			if (st == sf::Socket::Error) {
				for (int j = 1; j < nextSlave; j++)
					ls.tcpsocket[j].Close();
                
				snprintf(message, size, N_("Network error."));
				newState = LINK_ERROR;
			} else {
				sf::Packet packet;
				packet 	<< static_cast<sf::Uint16>(nextSlave)
                << static_cast<sf::Uint16>(lanlink.numslaves);
                
				ls.tcpsocket[nextSlave].Send(packet);
                
				snprintf(message, size, N_("Player %d connected"), nextSlave);
                
				lanlink.connectedSlaves++;
			}
		}
        
		if (lanlink.numslaves == lanlink.connectedSlaves) {
			for (int i = 1; i <= lanlink.numslaves; i++) {
				sf::Packet packet;
				packet 	<< true;
                
				ls.tcpsocket[i].Send(packet);
			}
            
			snprintf(message, size, N_("All players connected"));
			newState = LINK_OK;
		}
	} else {
        
		sf::Packet packet;
		sf::Socket::Status status = lanlink.tcpsocket.Receive(packet);
        
		if (status == sf::Socket::Error || status == sf::Socket::Disconnected) {
			snprintf(message, size, N_("Network error."));
			newState = LINK_ERROR;
		} else if (status == sf::Socket::Done) {
            
			if (linkid == 0) {
				sf::Uint16 receivedId, receivedSlaves;
				packet >> receivedId >> receivedSlaves;
                
				if (packet) {
					linkid = receivedId;
					lanlink.numslaves = receivedSlaves;
                    
					snprintf(message, size, N_("Connected as #%d, Waiting for %d players to join"),
                             linkid + 1, lanlink.numslaves - linkid);
				}
			} else {
				bool gameReady;
				packet >> gameReady;
                
				if (packet && gameReady) {
					newState = LINK_OK;
					snprintf(message, size, N_("All players joined."));
				}
			}
            
			sf::Selector<sf::SocketTCP> fdset;
			fdset.Add(lanlink.tcpsocket);
			fdset.Wait(0.1);
		}
	}
    
	return newState;
}

ConnectionState ConnectLinkUpdate(char * const message, size_t size)
{
	message[0] = '\0';
    
	if (!linkDriver || gba_connection_state != LINK_NEEDS_UPDATE) {
		gba_connection_state = LINK_ERROR;
		snprintf(message, size, N_("Link connection does not need updates."));
        
		return LINK_ERROR;
	}
    
	gba_connection_state = linkDriver->connectUpdate(message, size);
    
	return gba_connection_state;
}

void EnableLinkServer(bool enable, int numSlaves) {
	lanlink.server = enable;
	lanlink.numslaves = numSlaves;
}

void EnableSpeedHacks(bool enable) {
	lanlink.speed = enable;
}

bool SetLinkServerHost(const char *host) {
	sf::IPAddress addr = sf::IPAddress(host);
    
	lc.serveraddr = addr;
	joybusHostAddr = addr;
    
	return addr.IsValid();
}

void GetLinkServerHost(char * const host, size_t size) {
	if (host == NULL || size == 0)
		return;
    
	host[0] = '\0';
    
	if (linkDriver && linkDriver->mode == LINK_GAMECUBE_DOLPHIN)
		strncpy(host, joybusHostAddr.ToString().c_str(), size);
	else if (lanlink.server)
		strncpy(host, sf::IPAddress::GetLocalAddress().ToString().c_str(), size);
	else
		strncpy(host, lc.serveraddr.ToString().c_str(), size);
}

void SetLinkTimeout(int value) {
	linktimeout = value;
}

int GetLinkPlayerId() {
	if (GetLinkMode() == LINK_DISCONNECTED) {
		return -1;
	} else if (linkid > 0) {
		return linkid;
	} else {
		return vbaid;
	}
}

static void ReInitLink()
{
	int f = linkmem.linkflags;
	int n = linkmem.numgbas;
	if(f & (1 << linkid)) {
		systemMessage(0, N_("Lost link; reinitialize to reconnect"));
		return;
	}
	linkmem.linkflags |= 1 << linkid;
	if(n < linkid + 1)
		linkmem.numgbas = linkid + 1;
	numtransfers = linkmem.numtransfers;
	systemScreenMessage(_("Lost link; reconnected"));
}

static void CloseIPC() {
	int f = linkmem.linkflags;
	f &= ~(1 << linkid);
	if(f & 0xf) {
		linkmem.linkflags = f;
		int n = linkmem.numgbas;
		for(int i = 0; i < n; i--)
			if(f <= (1 << (i + 1)) - 1) {
				linkmem.numgbas = i + 1;
				break;
			}
	}
    
	for(i=0;i<4;i++){
		if(linksync[i]!=NULL){
#if (defined __WIN32__ || defined _WIN32)
			ReleaseSemaphore(linksync[i], 1, NULL);
			CloseHandle(linksync[i]);
#else
			sem_close(linksync[i]);
			if(!(f & 0xf)) {
				linkevent[sizeof(linkevent)-2]=(char)i+'1';
				sem_unlink(linkevent);
			}
#endif
		}
	}
#if (defined __WIN32__ || defined _WIN32)
	CloseHandle(mmf);
	UnmapViewOfFile(linkmem);
    
	// FIXME: move to caller
	// (but there are no callers, so why bother?)
	//regSetDwordValue("LAN", lanlink.active);
#else
	if(!(f & 0xf))
		shm_unlink("/" LOCAL_LINK_NAME);
    // GBARemove munmap(linkmem, sizeof(LINKDATA));
	close(mmf);
#endif
}

static void CloseSocket() {
	if(linkid){
		char outbuffer[4];
		outbuffer[0] = 4;
		outbuffer[1] = -32;
		if(lanlink.type==0) lanlink.tcpsocket.Send(outbuffer, 4);
	} else {
		char outbuffer[12];
		int i;
		outbuffer[0] = 12;
		outbuffer[1] = -32;
		for(i=1;i<=lanlink.numslaves;i++){
			if(lanlink.type==0){
				ls.tcpsocket[i].Send(outbuffer, 12);
			}
			ls.tcpsocket[i].Close();
		}
	}
	lanlink.tcpsocket.Close();
}

static void CloseRFUSocket()
{
    c_s.Lock();
    LinkFirstTime = true;
    c_s.Unlock();
    if(lanlink.connectedSlaves > 0)
    {
        DATALIST.clear();
    }
    
    RFUClear();
}

void CloseLink(void){
	if (!linkDriver) {
		return; // Nothing to do
	}
    
	linkDriver->close();
	linkDriver = NULL;
    
	return;
}

// call this to clean up crashed program's shared state
// or to use TCP on same machine (for testing)
// this may be necessary under MSW as well, but I wouldn't know how
void CleanLocalLink()
{
#if !(defined __WIN32__ || defined _WIN32)
	shm_unlink("/" LOCAL_LINK_NAME);
	for(int i = 0; i < 4; i++) {
		linkevent[sizeof(linkevent) - 2] = '1' + i;
		sem_unlink(linkevent);
	}
#endif
}

// Server
lserver::lserver(void){
	intinbuffer = (s32*)inbuffer;
	u16inbuffer = (u16*)inbuffer;
	intoutbuffer = (s32*)outbuffer;
	u16outbuffer = (u16*)outbuffer;
	oncewait = false;
}

void lserver::Send(void){
	if(lanlink.type==0){	// TCP
		if(savedlinktime==-1){
			outbuffer[0] = 4;
			outbuffer[1] = -32;	//0xe0
			for(i=1;i<=lanlink.numslaves;i++){
                
                GBALinkSendDataToPlayerAtIndex(i, outbuffer, 4);
				//tcpsocket[i].Send(outbuffer, 4);
				
                size_t nr;
                
                nr = GBALinkReceiveDataFromPlayerAtIndex(i, inbuffer, 4);
                //tcpsocket[i].Receive(inbuffer, 4, nr);
			}
		}
		outbuffer[1] = tspeed;
		WRITE16LE(&u16outbuffer[1], linkdata[0]);
		WRITE32LE(&intoutbuffer[1], savedlinktime);
		if(lanlink.numslaves==1){
			if(lanlink.type==0){
				outbuffer[0] = 8;
                
                GBALinkSendDataToPlayerAtIndex(1, outbuffer, 8);
				//tcpsocket[1].Send(outbuffer, 8);
			}
		}
		else if(lanlink.numslaves==2){
			WRITE16LE(&u16outbuffer[4], linkdata[2]);
			if(lanlink.type==0){
				outbuffer[0] = 10;
                
                GBALinkSendDataToPlayerAtIndex(1, outbuffer, 10);
				//tcpsocket[1].Send(outbuffer, 10);
				
                WRITE16LE(&u16outbuffer[4], linkdata[1]);
				
                GBALinkSendDataToPlayerAtIndex(2, outbuffer, 10);
                //tcpsocket[2].Send(outbuffer, 10);
			}
		} else {
			if(lanlink.type==0){
				outbuffer[0] = 12;
				WRITE16LE(&u16outbuffer[4], linkdata[2]);
				WRITE16LE(&u16outbuffer[5], linkdata[3]);
                
                GBALinkSendDataToPlayerAtIndex(1, outbuffer, 12);
				//tcpsocket[1].Send(outbuffer, 12);
                
                WRITE16LE(&u16outbuffer[4], linkdata[1]);
                
                GBALinkSendDataToPlayerAtIndex(2, outbuffer, 12);
				//tcpsocket[2].Send(outbuffer, 12);
				
                WRITE16LE(&u16outbuffer[5], linkdata[2]);
                
                GBALinkSendDataToPlayerAtIndex(3, outbuffer, 12);
				//tcpsocket[3].Send(outbuffer, 12);
                
			}
		}
	}
    ls.initd++;
	return;
}

void lserver::Recv(void){
	int numbytes;
	if(lanlink.type==0){	// TCP
		fdset.Clear();
		for(i=0;i<lanlink.numslaves;i++) fdset.Add(tcpsocket[i+1]);
		// was linktimeout/1000 (i.e., drop ms part), but that's wrong
        
        
		/*if (fdset.Wait((float)(linktimeout / 1000.)) == 0)
		{
			return;
		}*/
        
        if (!GBALinkWaitForLinkDataWithTimeout((linktimeout / 1000.)))
        {            
            numtransfers = 0;
            return;
        }
        
		howmanytimes++;
		for(i=0;i<lanlink.numslaves;i++){
			numbytes = 0;
			inbuffer[0] = 1;
			while(numbytes<howmanytimes*inbuffer[0]) {
				size_t nr;
                
                nr = GBALinkReceiveDataFromPlayerAtIndex(i+1, inbuffer+numbytes, howmanytimes*inbuffer[0]-numbytes);
				//tcpsocket[i+1].Receive(inbuffer+numbytes, howmanytimes*inbuffer[0]-numbytes, nr);
                
                numbytes += nr;
			}
			if(howmanytimes>1) memmove(inbuffer, inbuffer+inbuffer[0]*(howmanytimes-1), inbuffer[0]);
			if(inbuffer[1]==-32){
				char message[30];
				sprintf(message, _("Player %d disconnected."), i+2);
				systemScreenMessage(message);
				outbuffer[0] = 4;
				outbuffer[1] = -32;
				for(i=1;i<lanlink.numslaves;i++){
                    
                    GBALinkSendDataToPlayerAtIndex(i, outbuffer, 12);
					//tcpsocket[i].Send(outbuffer, 12);
					
                    
                    size_t nr;
                    
                    nr = GBALinkReceiveDataFromPlayerAtIndex(i, inbuffer, 256);
					//tcpsocket[i].Receive(inbuffer, 256, nr);
                    
					tcpsocket[i].Close();
				}
				CloseLink();
				return;
			}
			linkdata[i+1] = READ16LE(&u16inbuffer[1]);
		}
		howmanytimes = 0;
	}
	after = false;
    ls.initd--;
	return;
}

void CheckLinkConnection() {
	if (GetLinkMode() == LINK_CABLE_SOCKET) {
		if (linkid && lc.numtransfers == 0) {
			lc.CheckConn();
		}
	}
}

// Client
lclient::lclient(void){
	intinbuffer = (s32*)inbuffer;
	u16inbuffer = (u16*)inbuffer;
	intoutbuffer = (s32*)outbuffer;
	u16outbuffer = (u16*)outbuffer;
	numtransfers = 0;
	return;
}

void lclient::CheckConn(void){
	size_t nr;
    
    nr = GBALinkReceiveDataFromPlayerAtIndex(0, inbuffer, 1);
	//lanlink.tcpsocket.Receive(inbuffer, 1, nr);
	
    numbytes = (int)nr;
	if(numbytes>0){
		while(numbytes<inbuffer[0]) {
            
            nr = GBALinkReceiveDataFromPlayerAtIndex(0, inbuffer+numbytes, inbuffer[0] - numbytes);
			//lanlink.tcpsocket.Receive(inbuffer+numbytes, inbuffer[0] - numbytes, nr);
			
            numbytes += nr;
		}
		if(inbuffer[1]==-32){
			outbuffer[0] = 4;
            
            GBALinkSendDataToPlayerAtIndex(0, outbuffer, 4);
			//lanlink.tcpsocket.Send(outbuffer, 4);
			
            systemScreenMessage(_("Server disconnected."));
			CloseLink();
			return;
		}
		numtransfers = 1;
		savedlinktime = 0;
		linkdata[0] = READ16LE(&u16inbuffer[1]);
		tspeed = inbuffer[1] & 3;
		for(i=1, numbytes=4;i<=lanlink.numslaves;i++)
			if(i!=linkid) {
				linkdata[i] = READ16LE(&u16inbuffer[numbytes]);
				numbytes++;
			}
		after = false;
		oncewait = true;
	}
	return;
}

void lclient::Recv(void){
	fdset.Clear();
	// old code used socket # instead of mask again
	fdset.Add(lanlink.tcpsocket);
	// old code stripped off ms again
    
    
	/*if (fdset.Wait((float)(linktimeout / 1000.)) == 0)
	{
		numtransfers = 0;
		return;
	}*/
    
    if (!GBALinkWaitForLinkDataWithTimeout((linktimeout / 1000.)))
    {
        numtransfers = 0;
        return;
    }
    
	numbytes = 0;
	inbuffer[0] = 1;
	size_t nr;
	while(numbytes<inbuffer[0]) {
        
        nr = GBALinkReceiveDataFromPlayerAtIndex(0, inbuffer+numbytes, inbuffer[0] - numbytes);
		//lanlink.tcpsocket.Receive(inbuffer+numbytes, inbuffer[0] - numbytes, nr);
        
		numbytes += nr;
	}
	if(inbuffer[1]==-32){
		outbuffer[0] = 4;
        
        GBALinkSendDataToPlayerAtIndex(0, outbuffer, 4);
		//lanlink.tcpsocket.Send(outbuffer, 4);
        
		systemScreenMessage(_("Server disconnected."));
		CloseLink();
		return;
	}
	tspeed = inbuffer[1] & 3;
	linkdata[0] = READ16LE(&u16inbuffer[1]);
	savedlinktime = (s32)READ32LE(&intinbuffer[1]);
	for(i=1, numbytes=4;i<lanlink.numslaves+1;i++)
		if(i!=linkid) {
			linkdata[i] = READ16LE(&u16inbuffer[numbytes]);
			numbytes++;
		}
	numtransfers++;
	if(numtransfers==0) numtransfers = 2;
	after = false;
}

void lclient::Send(){
	outbuffer[0] = 4;
	outbuffer[1] = linkid<<2;
	WRITE16LE(&u16outbuffer[1], linkdata[linkid]);
    
    GBALinkSendDataToPlayerAtIndex(0, outbuffer, 4);
	//lanlink.tcpsocket.Send(outbuffer, 4);
	return;
}

bool LinkSendData(char *buf, int size, int nretry, int idx) {
    bool sent = true;
    c_s.Lock();
    if(linkid) //client
    {
        // GBARemove sent = lc.SendData(buf, size, nretry);
        //lc.Send();
    }
    else //server
    {
        // GBARemove sent = ls.SendData(buf, size, nretry, idx);
        //ls.Send();
    }
    c_s.Unlock();
    return(sent);
}

bool IsLinkConnected()
{
    return GetLinkMode() != LINK_DISCONNECTED;
}

u16 RFCheck(u16 value) //Called when COMM_RF_SIOCNT written
{
    if (gGba.mem.ioMem.b == NULL)
        return value;
    
    /*if (rfu_enabled && (READ16LE(&ioMem[RF_CNT]) & 0x80))*/ { //0x83
        //value &= 0xff7f;
        c_s.Lock();
        if((READ16LE(&gGba.mem.ioMem.b[RF_RECVCMD]) & 0xff)==0)
            UPDATE_REG(RF_RECVCMD, 0x3d); //value should be >=0x20 or 0x0..0x11 or 0x0..0x1f ? is this RFU cmd?
        c_s.Unlock();
    }
    
    //UPDATE_REG(COMM_RF_SIOCNT, value);
    return value;
}

void RFUClear()
{
}

#endif