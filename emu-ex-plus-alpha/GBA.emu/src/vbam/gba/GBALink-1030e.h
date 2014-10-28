#pragma once

#ifndef NO_LINK
#include <SFML/Network.hpp>
#endif

#ifdef _MSC_VER //#ifdef _WIN32
//#include "afxmt.h"						// AdamN: for CSingleLock
//#include "../Win32/WinHelper.h"			// AdamN: for CCriticalSection
#endif

#include <list>

typedef struct {
	u8 len; //data len in 32bit words
	u8 idx; //client idx
	u8 gbaid; //source id
	u8 qid; //target ids
	u32 sign; //signal
	u32 time; //linktime
	u32 data[255];
} rfu_datarec;

extern std::list<rfu_datarec> DATALIST;
extern std::list<rfu_datarec>::iterator DATALIST_I;
extern rfu_datarec tmpDataRec;

#define LINK_PARENTLOST 0x80
#define UNSUPPORTED -1
#define MULTIPLAYER 0
#define NORMAL8 1
#define NORMAL32 2 //AdamN: wireless use normal32 also
#define UART 3
#define JOYBUS 4
#define GP 5
#define INFRARED 6 //AdamN: Infrared Register at 4000136h
#define RFU_INIT 0
#define RFU_COMM 1
#define RFU_SEND 2
#define RFU_RECV 3

#define COMM_SIODATA32_L	0x120 //AdamN: Lower 16bit on Normal mode
#define COMM_SIODATA32_H	0x122 //AdamN: Higher 16bit on Normal mode
#define COMM_SIOMULTI0  	0x120 //AdamN: SIOMULTI0 (16bit) on MultiPlayer mode (Parent/Master)
#define COMM_SIOMULTI1  	0x122 //AdamN: SIOMULTI1 (16bit) on MultiPlayer mode (Child1/Slave1)
#define COMM_SIOMULTI2  	0x124 //AdamN: SIOMULTI2 (16bit) on MultiPlayer mode (Child2/Slave2)
#define COMM_SIOMULTI3  	0x126 //AdamN: SIOMULTI3 (16bit) on MultiPlayer mode (Child3/Slave3)
#define COMM_SIOCNT			0x128
#define COMM_SIODATA8		0x12a //AdamN: 8bit on Normal/UART mode, (up to 4x8bit with FIFO)
#define COMM_SIOMLT_SEND	0x12a //AdamN: SIOMLT_SEND (16bit R/W) on MultiPlayer mode (local outgoing)
#define COMM_RCNT			0x134 //AdamN: SIO Mode (4bit data) on GeneralPurpose mode
#define COMM_IR 			0x136 //AdamN: Infrared Register (16bit) 1bit data at a time(LED On/Off)?
#define COMM_JOYCNT			0x140
#define COMM_JOY_RECV_L		0x150 //AdamN: Send/Receive 8bit Lower first then 8bit Higher
#define COMM_JOY_RECV_H		0x152
#define COMM_JOY_TRANS_L	0x154 //AdamN: Send/Receive 8bit Lower first then 8bit Higher
#define COMM_JOY_TRANS_H	0x156
#define COMM_JOYSTAT		0x158 //AdamN: Send/Receive 8bit lower only

#define RF_RECVCMD			0x278 //AdamN: Unknown, Seems to be related to Wireless Adpater(RF_RCNT or armMode/CPSR or CMD sent by the adapter when RF_SIOCNT=0x83 or when RCNT=0x80aX?)
#define RF_CNT				0x27a //AdamN: Unknown, Seems to be related to Wireless Adpater(RF_SIOCNT?)		

#define JOYSTAT_RECV		2
#define JOYSTAT_SEND		8

#define JOYCNT_RESET			1
#define JOYCNT_RECV_COMPLETE	2
#define JOYCNT_SEND_COMPLETE	4
#define JOYCNT_INT_ENABLE		0x40

enum
{
	JOY_CMD_RESET	= 0xff,
	JOY_CMD_STATUS	= 0x00,
	JOY_CMD_READ	= 0x14,
	JOY_CMD_WRITE	= 0x15		
};

#ifdef _MSC_VER
typedef struct {
	u16 linkdata[4];
	u16 linkcmd[4];
	u16 numtransfers;
	s32 lastlinktime;
	u8 linkflags;
	u8 numgbas; //# of GBAs (max vbaid value plus 1), used in Single computer
	u8 rfu_recvcmd[5]; //last received command
	u8 rfu_proto[5]; // 0=UDP-like, 1=TCP-like protocols to see whether the data important or not (may or may not be received successfully by the other side)
	u16 rfu_qid[5];
	s32 rfu_q[5];
	u32 rfu_signal[5];
	u8 rfu_request[5]; //request to join
	//u8 rfu_joined[5]; //bool //currenlty joined
	u16 rfu_reqid[5]; //id to join
	u16 rfu_clientidx[5]; //only used by clients
	s32 rfu_linktime[5];
	s32 rfu_latency[5];
	u32 rfu_bdata[5][7]; //for 0x16/0x1d/0x1e?
	u32 rfu_gdata[5]; //for 0x17/0x19?/0x1e?
	u32 rfu_data[5][255]; //[32]; //for 0x24-0x26
	s32 rfu_state[5]; //0=none, 1=waiting for ACK
	u8  rfu_listfront[5];
	u8  rfu_listback[5];
	rfu_datarec rfu_datalist[5][256];
	/*u16 rfu_qidlist[5][256];
	u16 rfu_qlist[5][256];
	u32 rfu_datalist[5][256][255];
	u32 rfu_timelist[5][256];*/
} LINKDATA;

class lserver{
	int numbytes, lastern[5];
	fd_set fdset;
	timeval wsocktimeout;
	//timeval udptimeout;
public:
	char inbuffer[8192], outbuffer[8192]; //256
	int *intinbuffer;
	u16 *u16inbuffer;
	u32 *u32inbuffer;
	int *intoutbuffer;
	u16 *u16outbuffer;
	u32 *u32outbuffer;
	int insize, outsize, i, j;
	int counter;
	int done;
	int howmanytimes;
	int initd;
	SOCKET tcpsocket[5];
	SOCKADDR_IN udpaddr[5];
	bool connected[5];
	DWORD latency[5];
	lserver(void);
	int Init(void*);
	BOOL Send(void);
	BOOL Recv(void);
	int WaitForData(int ms);
	BOOL SendData(int size, int nretry = 0, int idx = 0);
	BOOL SendData(const char *buf, int size, int nretry = 0, int idx = 0);
	BOOL RecvData(int size, int idx, bool peek = false);
	int IsDataReady(void);
	int DiscardData(int idx);
};

class lclient{
	int lastern;
	fd_set fdset;
	timeval wsocktimeout;
public:
	char inbuffer[8192], outbuffer[8192]; //256;
	int *intinbuffer;
	u16 *u16inbuffer;
	u32 *u32inbuffer;
	int *intoutbuffer;
	u16 *u16outbuffer;
	u32 *u32outbuffer;
	int numbytes, insize, outsize, i, j;
	bool oncesend;
	SOCKADDR_IN serverinfo;
	SOCKET noblock;
	int numtransfers; //doesn't seems to be initialized?
	lclient(void);
	int Init(LPHOSTENT, void*);
	BOOL Send(void);
	BOOL Recv(void);
	void CheckConn(void);
	BOOL SendData(int size, int nretry = 0);
	BOOL SendData(const char *buf, int size, int nretry = 0);
	BOOL RecvData(int size, bool peek = false);
	BOOL WaitForData(int ms);
	BOOL IsDataReady(void);
	int DiscardData(void);
};

typedef struct {
	SOCKET tcpsocket;
	//SOCKET udpsocket;
	DWORD latency;
	int numgbas; //max vbaid/linkid value (# of GBAs minus 1), used in Networking
	HANDLE thread;
	u8 type;
	u8 server;
	bool terminate;
	bool connected;
	bool speed; //speedhack
	bool active; //network/single computer
	int mode;
} LANLINKDATA;

typedef struct {
	u16 Command;
	u16 Param;
} LINKCMDPRM;
#endif

extern int linktime;
extern bool gba_joybus_enabled;
extern bool gba_joybus_fast;
extern bool gba_joybus_peek;
extern bool gba_multiboot_ready;
extern int lastjoybusupdate;
extern int joybusinterval;
#ifndef NO_LINK
extern sf::IPAddress joybusHostAddr;
#endif
extern void JoyBusConnect();
extern void JoyBusShutdown();
extern void JoyBusDiscard();
extern void JoyBusUpdate(int ticks);
extern inline int GetSIOMode(u16 siocnt, u16 rcnt);

extern bool gba_link_enabled;
extern bool gba_link_auto;

#ifdef _MSC_VER
extern void LogStrPush(const char *str);
extern void LogStrPop(int len);
extern void LinkCmdQueue(u16 Cmd, u16 Prm);
extern void LinkConnected(bool b);
extern bool IsLinkConnected();
extern void gbLinkReset();
extern u8   gbStartLink(u8 b);
extern u16  gbLinkUpdate(u8 b);
extern u16  RFCheck(u16 value);
extern void StartLink(u16);
extern void StartLink2(u16);
extern void StartGPLink(u16);
extern void LinkSSend(u16);
extern void LinkUpdate(int);
extern void LinkUpdate2(int ticks, int FrameCnt);
extern void LinkChildStop();
extern void LinkChildSend(u16);
extern void CloseLink(); //CloseLanLink(); //AdamN: this should be CloseLink isn't?
extern void RFUClear();
extern int LinkDiscardData(int idx);
extern char *MakeInstanceFilename(const char *Input);
extern LANLINKDATA lanlink;
extern int vbaid;
extern bool speedhack;
extern bool rfu_enabled;
extern int linktimeout;
extern int linkbuffersize;
extern u8 gbSIO_SC;
extern lclient lc;
extern lserver ls;
extern int linkid;
extern bool linkdatarecvd[4];
extern bool LinkIsWaiting;
extern bool LinkFirstTime;
extern bool EmuReseted;
extern int EmuCtr;
//extern WinHelper::CCriticalSection c_s; //AdamN: critical section object to lock shared resource on multithread as CWnd is not thread-safe
//extern CCriticalSection m_CritSection;
//extern CSingleLock c_s; //(&m_CritSection);
extern int RetryCount;
extern int LinkCommand;
extern int LinkParam1;
extern int LinkParam2;
extern int LinkParam4;
extern int LinkParam8;
extern bool LinkHandlerActive;
//extern CPtrList LinkCmdList;
#else // These are stubbed for now
inline void StartLink(u16){}
inline void StartGPLink(u16){}
inline void LinkSSend(u16){}
inline void LinkUpdate(int){}
#endif
