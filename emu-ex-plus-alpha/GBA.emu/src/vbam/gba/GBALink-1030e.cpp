// This file was written by denopqrihg

#ifndef NO_LINK
#ifdef _WIN32
#include "../win32/stdafx.h"
#include "../win32/VBA.h"
#include "../win32/MainWnd.h"
#include "../win32/LinkOptions.h"
#include "../win32/Reg.h"
#endif

#include <stdio.h>
#include <errno.h>
#include "../common/Port.h"
#include "GBA.h"
#include "GBALink-1030e.h"
#include "GBASockClient.h"
#include "../gb/gbGlobals.h"

#ifdef _MSC_VER
#undef errno
#define errno WSAGetLastError()
//ern==10057 || ern==10051 || ern==10050 || ern==10065
#undef ECONNABORTED
#define ECONNABORTED WSAECONNABORTED
#undef ECONNRESET
#define ECONNRESET WSAECONNRESET
#undef ENOTCONN
#define ENOTCONN WSAENOTCONN
#undef EAGAIN
#define EAGAIN WSAEWOULDBLOCK
#undef EINPROGRESS
#define EINPROGRESS WSAEWOULDBLOCK
#undef EISCONN
#define EISCONN WSAEISCONN
#undef EALREADY
#define EALREADY WSAEALREADY
#undef ETIMEDOUT
#define ETIMEDOUT WSAETIMEDOUT
#undef ENETDOWN
#define ENETDOWN WSAENETDOWN
#undef ENETUNREACH
#define ENETUNREACH WSAENETUNREACH
#undef EHOSTUNREACH
#define EHOSTUNREACH WSAEHOSTUNREACH
#undef ECONNREFUSED
#define ECONNREFUSED WSAECONNREFUSED
#endif

// Joybus
bool gba_joybus_enabled = false;
bool gba_joybus_fast = false;
bool gba_joybus_peek = false; //true;
bool gba_multiboot_ready = false;
bool gba_mb_needsentclear = false;
u32 joybuslasttime = 0;
u32 jbcmdlasttime = 0;
int lastjoybusupdate = 0;
int joybusinterval = 10000; //12288; //5000; //20000; //4500; //2048; //40000; //3072; //256; //clock ticks

// If disabled, gba core won't call any (non-joybus) link functions
bool gba_link_enabled = false;
bool gba_link_auto = false;

#define UPDATE_REG(address, value) WRITE16LE(((u16 *)&ioMem[address]),value)

std::list<rfu_datarec> DATALIST;
std::list<rfu_datarec>::iterator DATALIST_I;
rfu_datarec tmpDataRec;

int linktime = 0; 
int tmpctr = 0;

GBASockClient* dol = NULL;
sf::IPAddress joybusHostAddr = sf::IPAddress::LocalHost;

#ifdef _MSC_VER
// Hodgepodge
u8 tspeed = 3;
u8 transfer = 0;
LINKDATA *linkmem = NULL;
LINKDATA rfudata;
int linkid = 0, vbaid = 0;
HANDLE linksync[5];
int savedlinktime = 0;
HANDLE mmf = NULL;
char linkevent[] = "VBA link event  ";
static int i, j;
int linktimeout = 1000; //2000
int linkbuffersize = 8192; //32767;
LANLINKDATA lanlink;
u16 linkdata[4];
bool linkdatarecvd[4];
u8 gbSIO_SC = 0;
lserver ls;
lclient lc;
bool oncewait = false, after = false;
bool speedhack = false;
bool LinkIsWaiting = false;
bool LinkFirstTime = true;
bool EmuReseted = true;
int EmuCtr = 0;
//WinHelper::CCriticalSection c_s; //AdamN: critical section object to lock shared resource on multithread as CWnd is not thread-safe
//CCriticalSection m_CritSection;
//CSingleLock c_s(&m_CritSection);
int RetryCount = 0;
int LinkCommand = 0;
int LinkParam1 = 0;
int LinkParam2 = 0;
int LinkParam4 = 0;
int LinkParam8 = 0;
extern bool LinkHandlerActive = false;
CPtrList LinkCmdList;
CString LogStr = _T("");

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
DWORD rfu_lasttime;
u32 rfu_buf;
int rfu_lastq; //u8
u16 rfu_lastqid;
u16 PrevVAL = 0;
u32 PrevCOM = 0, PrevDAT = 0;
// numtransfers seems to be used interchangeably with linkmem->numtransfers
// probably a bug?
int rfu_transfer_end, numtransfers = 0;
u8 rfu_numclients = 0; //# of clients joined
u8 rfu_curclient = 0; //currently client
u32 rfu_clientlist[5]; //list of clients joined, sorted by the time they joined (index 0 = first one joined), high-16bit may also contains index
s32 rfu_clientstate[5]; //0=none, 1=waiting for ACK
u32 rfu_masterdata[255]; //[5*35];//, rfu_cachedata[35]; //for 0x24-0x26, temp buffer before data actually sent to other gbas or cache after read
u32 rfu_bufferdata[64][256]; //buffer for masterdata from sockets (64 queues of GBAID + 255 words of data)
int rfu_bufferidx = 0;

// ???
int trtimedata[4][4] = { //clock ticks table?
	{34080, 8520, 5680, 2840},
	{65536, 16384, 10923, 5461},
	{99609, 24903, 16602, 8301},
	{133692, 33423, 22282, 11141}
};

int trtimeend[3][4] = { //clock ticks table?
	{72527, 18132, 12088, 6044},
	{106608, 26652, 17768, 8884},
	{133692, 33423, 22282, 11141}
};

int gbtime = 1024;

int GetSIOMode(u16, u16);

void LinkConnected(bool b);
bool IsLinkConnected();

BOOL LinkSendData(char *buf, int size, int nretry = 0, int idx = 0);
BOOL LinkRecvData(char *buf, int size, int idx, bool peek = false);
BOOL LinkIsDataReady(int *idx);
BOOL LinkWaitForData(int ms, int *idx);
int LinkDiscardData(int idx);
int LinkGetBufferSize(int opt = SO_SNDBUF);
BOOL LinkCanSend(int size);

DWORD WINAPI LinkClientThread(void *);
DWORD WINAPI LinkServerThread(void *);
DWORD WINAPI LinkHandlerThread(void *);

int StartServer(void);

u16 StartRFU(u16);
u16 StartRFU2(u16 value);
u16 StartRFU3(u16 value);
u16 StartRFU4(u16 value);
void RFUClear();

/* GBARemove #define CPUWriteByteQuick(addr, b) \
  ::map[(addr)>>24].address[(addr) & ::map[(addr)>>24].mask] = (b)
#define CPUWriteMemoryQuick(addr, b) \
  *((u32 *)&::map[(addr)>>24].address[(addr) & ::map[(addr)>>24].mask]) = (b)
#define CPUReadMemoryQuick(addr) \
  *((u32 *)&::map[(addr)>>24].address[(addr) & ::map[(addr)>>24].mask])*/

void LogStrPush(const char *str) {
	c_s.Lock();
	LogStr.AppendFormat(_T("%s(%08x)>"),str,GetTickCount());
	c_s.Unlock();
	return;
}

void LogStrPop(int len) {
	c_s.Lock();
	LogStr.Delete(LogStr.GetLength()-(len+11),(len+11));
	c_s.Unlock();
	return;
}

void LinkCmdQueue(u16 Cmd, u16 Prm) {
	LINKCMDPRM cmdprm;
	ULONG tmp, tmp2;
	//POSITION pos;
	cmdprm.Command = Cmd;
	cmdprm.Param = Prm;
	tmp = Prm;
	tmp = tmp << 16;
	tmp |= Cmd;
	tmp2 = 0;
	c_s.Lock();
	if((lanlink.connected /*|| !lanlink.active*/) && LinkCmdList.GetCount()<255) { //as Client GetCount usually no more than 4, as Server it can be alot more than 256 (flooded with LinkUpdate)
		if(LinkCmdList.GetCount()>0)
		tmp2 = (ULONG)*&LinkCmdList.GetTail(); //AdamN: check last command that hasn't been processed yet
		if((Cmd==8) && ((tmp2 & 0xffff)==Cmd)) { //AdamN: LinkUpdate could flood the command queue
			LinkCmdList.SetAt(LinkCmdList.GetTailPosition(),(void*)tmp); //AdamN: replace the value, doesn't need to delete the old value isn't? since it's not really a pointer
			//log("Add: %04X %04X\n",cmdprm.Command,cmdprm.Param);
		} else LinkCmdList.AddTail((void*)tmp);
		//if(LinkCmdList.GetCount()>1) log("Count: %d\n",LinkCmdList.GetCount());
	}
	c_s.Unlock();
	return;
}

char *MakeInstanceFilename(const char *Input)
{
	if (vbaid == 0)
		return (char *)Input;

	static char *result=NULL;
	if (result!=NULL)
		free(result);

	result = (char *)malloc(strlen(Input)+3);
	char *p = strrchr((char *)Input, '.');
	sprintf(result, "%.*s-%d.%s", (int)(p-Input), Input, vbaid+1, p+1);
	return result;
}

void gbLinkReset()
{
	LinkIsWaiting = false;
	LinkFirstTime = true;
	linkmem->linkcmd[linkid] = 0;
	linkmem->linkdata[linkid] = 0xff;
	return;
}

u8 gbStartLink(u8 b) //used on internal clock
{
  u8 dat = 0xff; //master (w/ internal clock) will gets 0xff if slave is turned off (or not ready yet also?)
  //if(linkid) return 0xff; //b; //Slave shouldn't be sending from here
  BOOL sent = false;
  //int gbSerialOn = (gbMemory[0xff02] & 0x80); //not needed?
  if(gba_link_auto) {
	  gba_link_enabled = true; //(gbMemory[0xff02]!=0); //not needed?
	  rfu_enabled = false;
  }
  if(!gba_link_enabled) return 0xff;
  if(!lanlink.active) { //Single Computer
	  u32 tm = GetTickCount();
	  do {
	  WaitForSingleObject(linksync[linkid], 1);
	  ResetEvent(linksync[linkid]);
	  } while (linkmem->linkcmd[linkid] && (GetTickCount()-tm)<(u32)linktimeout);
	  linkmem->linkdata[linkid] = b;
	  linkmem->linkcmd[linkid] = 1;
	  SetEvent(linksync[linkid]);

	  LinkIsWaiting = false;
	  tm = GetTickCount();
	  do {
	  WaitForSingleObject(linksync[1-linkid], 1);
	  ResetEvent(linksync[1-linkid]);
	  } while (!linkmem->linkcmd[1-linkid] && (GetTickCount()-tm)<(u32)linktimeout);
	  if(linkmem->linkcmd[1-linkid]) {
		dat = (u8)linkmem->linkdata[1-linkid];
		linkmem->linkcmd[1-linkid] = 0;
	  } //else LinkIsWaiting = true;
	  SetEvent(linksync[1-linkid]);

	  LinkFirstTime = true;
	  if(dat!=0xff/*||b==0x00||dat==0x00*/)
		LinkFirstTime = false;
	  
	  return dat;
  }
  if(IsLinkConnected()/*lanlink.connected*/) { //Network
	LogStrPush("gbStartLink");
	//Send Data (Master/Slave)
	if(linkid) { //Client
		lc.outbuffer[0] = 2;
		lc.outbuffer[1] = b;
		sent = lc.SendData(2, 1);
	} else //Server
	{
		ls.outbuffer[0] = 2;
		ls.outbuffer[1] = b;
		sent = ls.SendData(2, 1);
	}
	//if(linkid) return b;
	//Receive Data (Master)
	if(sent)
	//if(gbMemory[0xff02] & 1)
	if(linkid) { //Client
		if(lc.WaitForData(linktimeout)) { //-1 might not be getting infinity as expected :(
			if(lc.RecvData(2,true))
			if(lc.RecvData(lc.inbuffer[0]))
			dat = lc.inbuffer[1];
			//dat = b;
		}
	} else //Server
	{
		int idx;
		if((idx=ls.WaitForData(linktimeout))) { //-1 might not be getting infinity as expected :(
			if(ls.RecvData(2, idx, true))
			if(ls.RecvData(ls.inbuffer[0], idx))
			dat = ls.inbuffer[1];
			//dat = b;
		}
	}
	#ifdef GBA_LOGGING
		if(systemVerbose & VERBOSE_SIO) {
			log("sSIO : %02X  %02X->%02X  %d\n", gbSIO_SC, b, dat, GetTickCount() ); //register_LY
		}
	#endif
	LinkFirstTime = true;
	if(dat==0xff/*||b==0x00||dat==0x00*/) { //dat==0xff
		//LinkFirstTime = true;
		//if(dat==0xff)
		/*if(linkid) lc.DiscardData();
		else ls.DiscardData(1);*/
		LinkDiscardData(0); //for(int i=1; i<=lanlink.numgbas; i++) LinkDiscardData(i);
	} else //
	//if(!(gbMemory[0xff02] & 2)) //((gbMemory[0xff02] & 3) == 1) 
		LinkFirstTime = false; //it seems internal clocks can send 1(w/ speed=0) following data w/ external clock, does the speed declare how many followers that can be send?
    //if( /*(gbMemory[0xff02] & 2) ||*/ !(gbMemory[0xff02] & 1) ) LinkFirstTime = true;
	LinkIsWaiting = false;
	LogStrPop(11);
  }
  
  return dat;
}

u16 gbLinkUpdate(u8 b) //used on external clock
{
  u8 dat = b; //0xff; //slave (w/ external clocks) won't be getting 0xff if master turned off
  BOOL recvd = false;
  int idx = 0;
  int gbSerialOn = 0;
  if(gbMemory)
  gbSerialOn = (gbMemory[0xff02] & 0x80);
  if(gba_link_auto) {
	  gba_link_enabled = true; //(gbMemory[0xff02]!=0);
	  rfu_enabled = false;
  }
  if(gbSerialOn) {
  if(gba_link_enabled)
  if(!lanlink.active) { //Single Computer
	  u32 tm;// = GetTickCount();
	  //do {
	  WaitForSingleObject(linksync[1-linkid], linktimeout);
	  ResetEvent(linksync[1-linkid]);
	  //} while (!linkmem->linkcmd[1-linkid] && (GetTickCount()-tm)<(u32)linktimeout);
	  if(linkmem->linkcmd[1-linkid]) {
		dat = (u8)linkmem->linkdata[1-linkid];
		linkmem->linkcmd[1-linkid] = 0;
		recvd = true;
		LinkIsWaiting = false;
	  } else LinkIsWaiting = true;
	  SetEvent(linksync[1-linkid]);

	  if(!LinkIsWaiting) {
		  tm = GetTickCount();
		  do {
		  WaitForSingleObject(linksync[linkid], 1);
		  ResetEvent(linksync[linkid]);
		  } while (linkmem->linkcmd[1-linkid] && (GetTickCount()-tm)<(u32)linktimeout);
		  if(!linkmem->linkcmd[linkid]) {
			linkmem->linkdata[linkid] = b;
			linkmem->linkcmd[linkid] = 1;
		  }
		  SetEvent(linksync[linkid]);
	  }

  } else
  if(IsLinkConnected()/*lanlink.connected*/) { //Network
	//if(!gbSerialOn && !linkid) return (b<<8);
	LogStrPush("gbLinkUpd");
	//Receive Data (Slave)
	//if(!(gbMemory[0xff02] & 1))
	if(linkid) { //Client
		if((/*LinkFirstTime &&*/ lc.IsDataReady()) || ( !lanlink.speed && !LinkFirstTime && lc.WaitForData(linktimeout)) ) {
			if((recvd=lc.RecvData(2,true)))
			recvd = lc.RecvData(lc.inbuffer[0]);
			if(recvd /*&& gbSerialOn*/) { //don't update if not ready?
				dat = lc.inbuffer[1];
				//LinkFirstTime = false;
				//LinkFirstTime = true;
			} else LinkIsWaiting = true;
		} else LinkIsWaiting = true;
	} else //Server
	{
		if((/*LinkFirstTime &&*/ (idx=ls.IsDataReady())) || ( !lanlink.speed && !LinkFirstTime && (idx=ls.WaitForData(linktimeout))) ) {
			if((recvd=ls.RecvData(2, idx, true)))
			recvd = ls.RecvData(ls.inbuffer[0], idx);
			if(recvd /*&& gbSerialOn*/) { //don't update if not ready?
				dat = ls.inbuffer[1];
				//LinkFirstTime = false;
				//LinkFirstTime = true;
			} else LinkIsWaiting = true;
		} else LinkIsWaiting = true;
	}
	/*if(!linkid) //Master shouldn't be initiate a transfer from here
	{
		LogStrPop(9);
		return b; //returning b seems to make it as Player1
	}*/
	//Send Data (Master/Slave), slave should replies 0xff if it's not ready yet? OR don't change the data?
	//if(!LinkFirstTime) LinkFirstTime = true; else
	if(recvd)
	if(linkid) { //Client
		lc.outbuffer[0] = 2;
		//if(gbSerialOn)
		lc.outbuffer[1] = b; //else lc.outbuffer[1] = (u8)0xff;
		if(gbSerialOn) //don't reply if not ready?
		lc.SendData(2, 1);
		LinkIsWaiting = false;
		//LinkFirstTime = false;
	} else //Server
	{
		ls.outbuffer[0] = 2;
		//if(gbSerialOn)
		ls.outbuffer[1] = b; //else ls.outbuffer[1] = (u8)0xff;
		if(gbSerialOn) //don't reply if not ready?
		ls.SendData(2, 1, idx);
		LinkIsWaiting = false;
		//LinkFirstTime = false;
	}
	#ifdef GBA_LOGGING
		if(recvd && gbSerialOn)
		if(systemVerbose & VERBOSE_SIO) {
			log("cSIO : %02X  %02X->%02X  %d\n", gbSIO_SC, b, dat, GetTickCount() ); //register_LY
		}
	#endif
	
	if(dat==0xff)
		  LinkDiscardData(0); //for(int i=1; i<=lanlink.numgbas; i++) LinkDiscardData(i);
	  /*if(linkid) lc.DiscardData();
	  else ls.DiscardData(1);*/
	LogStrPop(9);
  }
  if(dat==0xff/*||dat==0x00||b==0x00*/) //dat==0xff||dat==0x00
	  LinkFirstTime = true;
  /*if(recvd && gbMemory) //(dat & 1) 
  {
	gbMemory[0xff02] &= 0x7f;
	gbSerialOn = 0;
	gbMemory[0xff0f] = register_IF |= 8;
  }*/
  }
  return ((dat << 8) | (recvd & (u8)0xff));
}

void StartLink2(u16 value) //Called when COMM_SIOCNT written
{
	char inbuffer[8192], outbuffer[8192];
	u16 *u16inbuffer = (u16*)inbuffer;
	u16 *u16outbuffer = (u16*)outbuffer;
	BOOL disable = true;
	BOOL sent = false;
	unsigned long notblock = 1; //AdamN: 0=blocking, non-zero=non-blocking
	//unsigned long arg = 0;
	//fd_set fdset;
	//timeval wsocktimeout;
	
	if (ioMem == NULL)
		return;

	/*if (rfu_enabled) {
		UPDATE_REG(COMM_SIOCNT, StartRFU(value));
		return;
	}*/
	if (rfu_enabled) {
		//if(lanlink.connected)
			UPDATE_REG(COMM_SIOCNT, StartRFU3(value)); //RF use NORMAL32 mode to communicate
		//else UPDATE_REG(COMM_SIOCNT, StartRFU(value)); //RF use NORMAL32 mode to communicate

		return;
	}


	u16 rcnt = READ16LE(&ioMem[COMM_RCNT]);
	u16 siocnt = READ16LE(&ioMem[COMM_SIOCNT]);
	int commmode = GetSIOMode(value, rcnt);
	if(!linkid && (((siocnt&3) != (value&3)) || (GetSIOMode(siocnt, rcnt) != commmode))) linkdatarecvd[/*0*/linkid]=false; //AdamN: reset if clock/mode changed from the last time
	switch (commmode) {
	case MULTIPLAYER: 
		if (value & 0x08) { //AdamN: SD Bit.3=1 (All GBAs Ready)
			if(lanlink.active && IsLinkConnected()/*lanlink.connected*/)
			if (/*!(value & 0x04)*/ !linkid) { //Parent/Master, AdamN: SI Bit.2=0 (0=Parent/Master/Server,1=Child/Slave/Client)
				if (value & 0x80) //AdamN: Start/Busy Bit.7=1 (Active/Transfering)
				if(!linkdatarecvd[0]) { //AdamN: cycle not started yet
					UPDATE_REG(COMM_SIOCNT, READ16LE(&ioMem[COMM_SIOCNT]) | 0x0080); //AdamN: Activate bit.7 (Start/Busy) since value hasn't been updated yet at this point
					UPDATE_REG(COMM_RCNT, READ16LE(&ioMem[COMM_RCNT]) & 0xfffe); //AdamN: LOWering bit.0 (SC)
					linkdata[0] = READ16LE(&ioMem[COMM_SIOMLT_SEND]);
					linkdata[1] = 0xffff;
					WRITE32LE(&linkdata[2], 0xffffffff);
					WRITE32LE(&ioMem[COMM_SIOMULTI0], 0xffffffff); //AdamN: data from SIOMULTI0 & SIOMULTI1
					WRITE32LE(&ioMem[COMM_SIOMULTI2], 0xffffffff); //AdamN: data from SIOMULTI2 & SIOMULTI3					
					outbuffer[0] = 4; //4 //AdamN: size of packet
					outbuffer[1] = linkid; //AdamN: Sender ID (0)
					u16outbuffer[1] = linkdata[0]; //AdamN: u16outbuffer[1] points to outbuffer[2]
					for(int i=1; i<=lanlink.numgbas; i++) {
						notblock = 0; //1;
						ioctlsocket(ls.tcpsocket[i], FIONBIO, &notblock); //AdamN: temporarily use non-blocking for sending multiple data at once
						int ern=errno; //errno;
						if(ern!=0) log("IOCTL1 Error: %d\n",ern);
						#ifdef GBA_LOGGING
							if(systemVerbose & VERBOSE_LINK) {
								log("%sSSend to : %d  Size : %d  %s\n", (LPCTSTR)LogStr, i, 4, (LPCTSTR)DataHex(outbuffer,4));
							}
						#endif
						/*outbuffer[0] = 0;
						for(int c=0;c<8;c++) //AdamN: sending 8 bytes dummies
							send(ls.tcpsocket[i], outbuffer, 1, 0); //send a dummies, it seems the first packet won't arrive on the other side for some reason, like need to fill the internal buffer before it actually get sent
						outbuffer[0] = 4;*/
						setsockopt(ls.tcpsocket[i], IPPROTO_TCP, TCP_NODELAY, (char*)&disable, sizeof(BOOL)); //true=send packet immediately
						sent|=(send(ls.tcpsocket[i], outbuffer, 4, 0)>=0);
						ern=errno; //errno;
						if(ern!=0) log("Send%d Error: %d\n",i,ern);
					}
					/*notblock = 0;
					ioctlsocket(ls.tcpsocket[i], FIONBIO, &notblock); //AdamN: back to blocking, might not be needed
					ern=errno;
					if(ern!=0) log("IOCTL2 Error: %d\n",ern);*/
					if(sent) {
						UPDATE_REG(COMM_SIOMULTI0, linkdata[0]); //AdamN: SIOMULTI0 (16bit data received from master/server)
						UPDATE_REG(COMM_RCNT, READ16LE(&ioMem[COMM_RCNT]) & 0xfff7); //AdamN: LOWering SO bit.3 (RCNT or SIOCNT?)
						for(int i=1; i<=lanlink.numgbas; i++) linkdatarecvd[i] = false; //AdamN: new cycle begins
						linkdatarecvd[0] = true;
						//value &= 0xff7f; //AdamN: Deactivate bit.7 (Start/Busy), Busy bit should be Deactivated when all SIOMULTI has been filled with data from active GBAs
						//value |= (sent != 0) << 7; 
					}
				}
			} else { //Slave/Client?
				//todo: ignoring ReadOnly bits on Slaves, is this needed?
				if (value & 0x80) log("Slave wants to Send");
			}
			/*value &= 0xff8b; //AdamN: bit.2(SI),4-5(ID),6(ERR) masked out
			//if(sent) 
				value |= (linkid ? 0xc : 8); //AdamN: master=0x08 bit.3(SD), slave=0x0c bit.2-3(SI,SD)
			value |= linkid << 4; //AdamN: setting bit.4-5 (ID) after a successful transfer*/
		}
		value &= 0xff8b; //AdamN: bit.2(SI),4-5(ID),6(ERR) masked out
		value |= 8; //AdamN: need to be set as soon as possible for Mario Kart
		/*if(sent)*/ {
			value |= (linkid ? 0xc : 8); //AdamN: master=0x08 bit.3(SD), slave=0x0c bit.2-3(SI,SD)
			value |= linkid << 4; //AdamN: setting bit.4-5 (ID) after a successful transfer, need to be set as soon as possible otherwise Client may think it's a Server(when getting in-game timeout) and tried to initiate a transfer on next retry
		}
		UPDATE_REG(COMM_SIOCNT, value);
		if(linkid && (value & 0x3f)==0x0f) lc.WaitForData(linktimeout/*-1*/); else
		if(sent) {
			ls.WaitForData(linktimeout/*-1*/);
			//MSG msg;
			//int ready = 0;
			//do { //Waiting for incomming data before continuing CPU execution
			//	SleepEx(1,true); //SleepEx(0,true); //to give time for incoming data
			//	if(PeekMessage(&msg, 0/*theApp.GetMainWnd()->m_hWnd*/,  0, 0, PM_NOREMOVE))
			/*		theApp.PumpMessage(); //seems to be processing message only if it has message otherwise it halt the program
				
				//fdset.fd_count = lanlink.numgbas;
				notblock = 0;
				for(int i=1; i<=lanlink.numgbas; i++) {
					//fdset.fd_array[i-1] = ls.tcpsocket[i];
					ioctlsocket(ls.tcpsocket[i], FIONBIO, &notblock); //AdamN: temporarily use blocking for reading
					int ern=errno;
					if(ern!=0) {
						log("slIOCTL Error: %d\n",ern);
						//if(ern==10054 || ern==10053 || ern==10057 || ern==10051 || ern==10050 || ern==10065) lanlink.connected = false;
					}
					arg = 1; //0;
					if(ioctlsocket(ls.tcpsocket[i], FIONREAD, &arg)!=0) { //AdamN: Alternative(Faster) to Select(Slower)
						int ern=errno; 
						if(ern!=0) {
							log("%sSC Error: %d\n",(LPCTSTR)LogStr,ern);
							char message[40];
							lanlink.connected = false;
							sprintf(message, _T("Player %d disconnected."), i+1);
							MessageBox(NULL, message, _T("Link"), MB_OK);
							break;
						}
					}
					if(arg>0) ready++;
				}
				//wsocktimeout.tv_sec = linktimeout / 1000;
				//wsocktimeout.tv_usec = linktimeout % 1000; //0; //AdamN: remainder should be set also isn't?
				//ready = select(0, &fdset, NULL, NULL, &wsocktimeout);
				//int ern=errno;
				//if(ern!=0) {
				//	log("slCC Error: %d\n",ern);
				//	if(ern==10054 || ern==10053 || ern==10057 || ern==10051 || ern==10050 || ern==10065) lanlink.connected = false;
				//}
			} while (lanlink.connected && ready==0);*/
		}
		
		//AdamN: doesn't seems to be needed here
		if (linkid) //Slave
			UPDATE_REG(COMM_RCNT, 7); //AdamN: Bit.0-2 (SC,SD,SI) as for GP
		else //Master
			UPDATE_REG(COMM_RCNT, 3); //AdamN: Bit.0-1 (SC,SD) as for GP //not needed
		if(sent || (linkid && (value & 0x3f)==0x0f))
			LinkUpdate2(0,0);
		break;
	case NORMAL8:
	case NORMAL32: //AdamN: Wireless mode also use NORMAL32 mode for transreceiving the data
	case UART:
	default:
		UPDATE_REG(COMM_SIOCNT, value);
		break;
	}
}

u16 RFCheck(u16 value) //Called when COMM_RF_SIOCNT written
{
	if (ioMem == NULL)
		return value;

	/*if (rfu_enabled && (READ16LE(&ioMem[RF_CNT]) & 0x80))*/ { //0x83
		//value &= 0xff7f;
		c_s.Lock();
		if((READ16LE(&ioMem[RF_RECVCMD]) & 0xff)==0)
		UPDATE_REG(RF_RECVCMD, 0x3d); //value should be >=0x20 or 0x0..0x11 or 0x0..0x1f ? is this RFU cmd?
		c_s.Unlock();
	}

	//UPDATE_REG(COMM_RF_SIOCNT, value);
	return value;
}

void StartLink(u16 value) //Called when COMM_SIOCNT written
{
	if (ioMem == NULL)
		return;

	if(value)
	switch (GetSIOMode(value, READ16LE(&ioMem[COMM_RCNT]))) { //
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
	case JOYBUS:
		if(gba_link_auto) {
			rfu_enabled = false;
			//gba_link_enabled = false;
			gba_joybus_enabled = true;
		}
		//break;
	default:
		if(gba_link_auto) gba_link_enabled = false;
	}

	if (((READ16LE(&ioMem[COMM_SIOCNT]) & 0x5080)==0x1000) && ((value & 0x5080)==0x5080)) { //RFU Reset, may also occur before cable link started
		#ifdef GBA_LOGGING
			if(systemVerbose & (VERBOSE_SIO | VERBOSE_LINK)) {
				log("RFU Reset2 : %04X  %04X  %d\n", READ16LE(&ioMem[COMM_RCNT]), READ16LE(&ioMem[COMM_SIOCNT]), GetTickCount() );
			}
		#endif
		
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
			LinkDiscardData(0); 
		}
		c_s.Lock();
		DATALIST.clear();
		linkmem->rfu_listfront[vbaid] = 0;
		linkmem->rfu_listback[vbaid] = 0;
		c_s.Unlock();
	}

	if (gba_link_enabled && rfu_enabled) {
		if(IsLinkConnected()/*lanlink.connected*/)
			UPDATE_REG(COMM_SIOCNT, StartRFU4(value)); //Network
		else UPDATE_REG(COMM_SIOCNT, StartRFU2(value)); //SingleComputer

		return;
	} else {
		if ((value & 0x5080)==0x5080) { //0x5083 //game tried to send wireless command but w/o the adapter
			/*if (value & 8) //Transfer Enable Flag Send (bit.3, 1=Disable Transfer/Not Ready)
				value &= 0xfffb; //Transfer enable flag receive (0=Enable Transfer/Ready, bit.2=bit.3 of otherside)	// A kind of acknowledge procedure
			else //(Bit.3, 0=Enable Transfer/Ready)
				value |= 4; //bit.2=1 (otherside is Not Ready)*/

			if (READ16LE(&ioMem[COMM_SIOCNT]) & 0x4000) //IRQ Enable
			{
				IF |= 0x80; //Serial Communication
				UPDATE_REG(0x202, IF); //Interrupt Request Flags / IRQ Acknowledge
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

	BOOL sent = false;
	//u16 prvSIOCNT = READ16LE(&ioMem[COMM_SIOCNT]);

	switch (GetSIOMode(value, READ16LE(&ioMem[COMM_RCNT]))) {
	case MULTIPLAYER: 
		if (value & 0x80) { //AdamN: Start.Bit=Start/Active (transfer initiated)
			if (!linkid) { //is master/server?
				if (!transfer) { //not in the middle of transfering previous data?
					if (lanlink.active) //On Networks
					{
						if (IsLinkConnected()/*lanlink.connected*/)
						{
							linkdata[0] = READ16LE(&ioMem[COMM_SIODATA8]); //AdamN: SIOMLT_SEND(16bit data to be sent) on MultiPlayer mode
							savedlinktime = linktime;
							tspeed = value & 3;
							LogStrPush("StartLink1");
							sent = ls.Send(); //AdamN: Server need to send this often, initiate data exchange
							LogStrPop(10);
							if(sent) {
							transfer = 1;
							linktime = 0;
							UPDATE_REG(COMM_SIODATA32_L, linkdata[0]); //AdamN: SIOMULTI0 (16bit data received from master/server)
							UPDATE_REG(COMM_SIODATA32_H, 0xffff); //AdamN: SIOMULTI1 (16bit data received from slave1, reset to FFFFh upon transfer start)
							WRITE32LE(&ioMem[0x124], 0xffffffff); //AdamN: data from SIOMULTI2 & SIOMULTI3
							if (lanlink.speed && oncewait == false) //lanlink.speed = speedhack
								ls.howmanytimes++;
							after = false;
							}
						}
					}
					else if (linkmem->numgbas > 1) //On Single Computer
					{
						ResetEvent(linksync[0]);
						linkmem->linkcmd[0] = ('M' << 8) + (value & 3);
						linkmem->linkdata[0] = READ16LE(&ioMem[COMM_SIODATA8]);

						if (linkmem->numtransfers != 0)
							linkmem->lastlinktime = linktime;
						else
							linkmem->lastlinktime = 0;

						if ((++linkmem->numtransfers) == 0)
							linkmem->numtransfers = 2;
						transfer = 1;
						linktime = 0;
						tspeed = value & 3;
						WRITE32LE(&ioMem[COMM_SIODATA32_L], 0xffffffff);
						WRITE32LE(&ioMem[0x124], 0xffffffff); //COMM_SIOMULTI2
						sent = true;
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

void RFUClear()
{
	if(linkmem) {
	c_s.Lock();
	//while (linkmem->rfu_signal[vbaid]) {
	linkmem->rfu_signal[vbaid] = 0;
	linkmem->rfu_request[vbaid] = 0;
	//SleepEx(1,true);
	//}
	//linkmem->rfu_q[vbaid] = 0;
	linkmem->rfu_bdata[vbaid][0] = 0;
	//gbaid = vbaid;
	c_s.Unlock();
	}
	return;
}

void StartGPLink(u16 value) //Called when COMM_RCNT written
{
	u16 oldval = READ16LE(&ioMem[COMM_RCNT]);
	UPDATE_REG(COMM_RCNT, value);

	u16 siocnt = READ16LE(&ioMem[COMM_SIOCNT]);
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
	case JOYBUS:
		if(gba_link_auto) {
			rfu_enabled = false;
			//gba_link_enabled = false;
			gba_joybus_enabled = true;
		}
		//break;
	default:
		if(gba_link_auto) gba_link_enabled = false;
	}

	/*if(rfu_enabled)*/ {
		c_s.Lock();
		if((READ16LE(&ioMem[RF_RECVCMD]) & 0xff)==0)
		UPDATE_REG(RF_RECVCMD, 0x3d); //value should be >=0x20 or 0x0..0x11 or 0x0..0x1f ? is this RFU cmd?
		c_s.Unlock();
	}

	if (!value)
		return; //if value=0(bit.15=1 & bit.14=0 for GP) then it's not possible for GP mode

	switch (GetSIOMode(READ16LE(&ioMem[COMM_SIOCNT]), value)) { //bit.15=0 & bit.14=any for MP/Normal/UART
	case MULTIPLAYER: 
		value &= 0xc0f0;
		value |= 3;
		if (linkid)
			value |= 4;
		UPDATE_REG(COMM_SIOCNT, ((READ16LE(&ioMem[COMM_SIOCNT])&0xff8b)|(linkid ? 0xc : 8)|(linkid<<4)));
		break;

	case JOYBUS:
		if (oldval!=0xc000) { //unlike real cable connection, in emulation the otherside (master) might not know that the slave is reseting joybus, so it's better not to do it? (but GBA might not be able to show the Map after joybus timeout)
			//if (gba_joybus_enabled)
			//JoyBusUpdate(0); //Test5 //0
			//UPDATE_REG(COMM_JOYSTAT, READ16LE(&ioMem[COMM_JOYSTAT]) & ~(JOYSTAT_SEND|JOYSTAT_RECV)); //0
			UPDATE_REG(COMM_JOYCNT, READ16LE(&ioMem[COMM_JOYCNT]) | JOYCNT_RESET); //treats it as reset cmd when joybus is reconnected
			lastjoybusupdate = linktime + 30000; //giving more time for GBA to clean up on reset
			if (READ16LE(&ioMem[COMM_JOYCNT]) & JOYCNT_INT_ENABLE)
			{
				IF |= 0x80;
				UPDATE_REG(0x202, IF);
			}
			#ifdef GBA_LOGGING
				if(systemVerbose & (VERBOSE_SIO | VERBOSE_LINK)) {
					log("%d : JoyBus Reset [TimeOut]\n",GetTickCount());
				}
			#endif
		}
		break;
	
	case GP: //Only bit.0-3&14-15 of RCNT used for GP, JoyBus use bit.15=1 & bit.14=1
	//default: //Normal mode, may cause problem w/ RF if default also reset the RF
		if (rfu_enabled) {
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
				linkmem->rfu_request[gbaid] &= ~(1<<vbaid); //linkmem->rfu_request[gbaid] = 0; //needed to detect MarioGolfAdv client exiting lobby
				SetEvent(linksync[gbaid]); //allow other gba to move
			}
			linkmem->rfu_signal[vbaid] = 0;
			linkmem->rfu_request[vbaid] = 0;
			//linkmem->rfu_q[vbaid] = 0; //need to give a chance for other side to receive the last data before exiting multiplayer game
			linkmem->rfu_proto[vbaid] = 0;
			linkmem->rfu_qid[vbaid] = 0;
			linkmem->rfu_reqid[vbaid] = 0;
			linkmem->rfu_linktime[vbaid] = 0;
			linkmem->rfu_latency[vbaid] = -1;
			linkmem->rfu_bdata[vbaid][0] = 0;
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
			#ifdef GBA_LOGGING
				if(systemVerbose & (VERBOSE_SIO | VERBOSE_LINK)) {
					if (!(READ16LE(&ioMem[COMM_RCNT])==0x8000 && (READ16LE(&ioMem[COMM_SIOCNT]) & 0xdfff)==0)) //to prevent MarioGolfAdvTour to show this during intro/menu
					log("RFU Reset1 : %04X  %04X  %d\n", READ16LE(&ioMem[COMM_RCNT]), READ16LE(&ioMem[COMM_SIOCNT]), GetTickCount() );
				}
			#endif
		}
		break;
	}
}

#endif // _MSC_VER

void JoyBusConnect()
{
	c_s.Lock();
	delete dol;
	dol = NULL;

	dol = new GBASockClient(joybusHostAddr);
	c_s.Unlock();
}

void JoyBusShutdown()
{
	c_s.Lock();
	if(dol /*&& dol->IsValid()*/) dol->Close();
	delete dol;
	dol = NULL;
	c_s.Unlock();
}

void JoyBusDiscard()
{
	c_s.Lock();
	if(dol && dol->connected) dol->DiscardData();
	c_s.Unlock();
}

u32 MBRegen(u32 n)
{
	return ((((((n*0x6177614b)+1) & ~0x00E0) ^ 0x00A0) & ~0x8000) | 0x8000);
}

u32 MBDecrypt(u32 data, u32 &seed, const u32 addr = 0x20000c0)
{
	seed = (seed*0x6177614b)+1; //"Kawa"
	return (((data ^ seed) ^ (0-addr)) ^ 0x20796220); //" by "
}

int MBDecrypt(const u32 *buf, int size, u32 &seed, const u32 base = 0x20000c0) //size in bytes
{
	//static const char mbkey[13] = " by Kawasedo";
	//static u32 seed = 0;
	if (!buf) return 0;
	/*for (int i=0; i<(size/4); i++) {
		seed = (seed*0x6177614b)+1;
		*((u32*)&buf[i]) = (((buf[i] ^ seed) ^ (0-(base+(i<<2)))) ^ 0x20796220);
	}*/
	int i = 0, sz = (size>>2)<<2;
	while (i<sz) {
		seed = (seed*0x6177614b)+1; //"Kawa"
		//*((u32*)(&buf+i)) = (((*((u32*)(&buf+i)) ^ seed) ^ (0-(base+i))) ^ 0x20796220); //" by "
		WRITE32LE(&buf+i, ((READ32LE(&buf+i) ^ seed) ^ (0-(base+i))) ^ 0x20796220); //" by "
		i += 4;
	}
	return sz; //min(size,$89)
}

void MBJoybus(u8 cmd)
{
	static u32 jblasttime = 0;
	static u32 n = 0;
	static u32 seed = 0;
	static int ofs = 0;
	static u8 idx = 0;
	static bool DL = false;
	
	if (idx==0) {
		n = 0xDDC0AAB0;
		seed = n;
		WRITE32LE(((u32 *)&ioMem[COMM_JOY_TRANS_L]), 0);
		UPDATE_REG(COMM_JOYSTAT, (READ16LE(&ioMem[COMM_JOYSTAT]) & 0xffcd) | JOYSTAT_SEND | idx);
		jblasttime = GetTickCount();
	}
	if (GetTickCount()-jblasttime>=16) {
		n = MBRegen(n);
		jblasttime = GetTickCount();
	}
	if (cmd==JOY_CMD_STATUS) {
		if (idx==0x10) {
			WRITE32LE(((u32 *)&ioMem[COMM_JOY_TRANS_L]), n ^ 0x6F646573); //"sedo"
			UPDATE_REG(COMM_JOYSTAT, (READ16LE(&ioMem[COMM_JOYSTAT]) & 0xffcd) | JOYSTAT_SEND | idx);
		}
	}
	if (READ16LE(&ioMem[COMM_JOYSTAT]) & JOYSTAT_RECV) { //ToDo: the last word received (right before the 2nd cmd 0x14) also decrypted but not important?
		u32 dat = READ32LE(&ioMem[COMM_JOY_RECV_L]);
		idx = READ16LE(&ioMem[COMM_JOYSTAT]) & 0x30;
		bool ok = ((idx & 0x20)!=0);
		idx ^= 0x10;
		if (idx<0x20) idx += 0x20;
		UPDATE_REG(COMM_JOYSTAT, (READ16LE(&ioMem[COMM_JOYSTAT]) & 0xffcd) | idx ); //& ~JOYSTAT_RECV
		if (ok) {
			if (ofs>=0xc0) dat = MBDecrypt(dat, seed, 0x2000000+ofs);
			WRITE32LE(((u32 *)&workRAM[ofs]), dat);
			ofs += 4;
		}
	}
	if (cmd==JOY_CMD_READ) { //(!(READ16LE(&ioMem[COMM_JOYSTAT]) & JOYSTAT_SEND))
		WRITE32LE(((u32 *)&ioMem[COMM_JOY_TRANS_L]), n ^ 0x6F646573); //"sedo"
		DL = !DL;
		if (!DL) {
			CPUWriteMemoryQuick(0x2000000, 0xEA000036);
			CPUWriteMemoryQuick(0x4000154, CPUReadMemoryQuick(0x20001f8)*CPUReadMemoryQuick(0x20001fc)); //COMM_JOY_TRANS_L //ToDo: 0 only works with Zelda - Four Swords, other games use different value
			gba_multiboot_ready = true;
			gba_mb_needsentclear = true;
			ofs = 0;
			n = 0;
			seed = 0;
			idx = 0;
			UPDATE_REG(COMM_JOYCNT, 0x40/*READ16LE(&ioMem[COMM_JOYCNT]) | JOYCNT_INT_ENABLE*/);
			//UPDATE_REG(0x200, READ16LE(&ioMem[0x200]) | 0x80); //IE : SIO IRQ
			CPUWriteByteQuick(0x20000c4, 0x01); //joybus boot mode
			CPUWriteByteQuick(0x3fffffa, 0x05); //mark it as ready to execute downloaded multiboot program
			jblasttime = GetTickCount();
		}
		//if(cmd==JOY_CMD_RESET) UPDATE_REG(COMM_JOYSTAT, (READ16LE(&ioMem[COMM_JOYSTAT]) & 0xff00) | 0x18); else
		UPDATE_REG(COMM_JOYSTAT, (READ16LE(&ioMem[COMM_JOYSTAT]) & 0xffcd) | JOYSTAT_SEND | idx);
	}
	if(cmd==JOY_CMD_RESET) {
		idx = 0x10;
		n = 0xDDC0AAB0;
		seed = n;
		jblasttime = GetTickCount();
	} 
}

void JoyBusUpdate2(int ticks)
{
    if (!ioMem) return;

    linktime += ticks;
    static int lastjoybusupdate = 0;

	if (reg[14].I==0x138 || reg[13].I>0x03007F00) return; //inside IRQ handler
    // Kinda ugly hack to update joybus stuff intermittently
    if (linktime > lastjoybusupdate)
    {
        lastjoybusupdate = linktime + joybusinterval; //0x3000; //may need to use higher value when using Turbo to maintain stability

        u16 jst = READ16LE(&ioMem[COMM_JOYSTAT]);
		u16 jct = READ16LE(&ioMem[COMM_JOYCNT]);
        if ((READ16LE(&ioMem[COMM_RCNT]) & 0xc000)==0xc000) //SIO is in JOYBUS mode
        if (/*((jst & JOYSTAT_SEND) || !(jst & JOYSTAT_RECV)) &&*/ (jct & JOYCNT_INT_ENABLE)) //if GBA have unsent data OR previous data from GameCube already read
        /*if (!(jct & 0x07))*/ { //GBA is expecting a new command

        char data[5] = {0x10, 0, 0, 0, 0}; // init with invalid cmd
        std::vector<char> resp;

        if (!dol)
            JoyBusConnect(); //may cause a lag w/o dolphin connected

        u8 cmd = dol->ReceiveCmd(data);
        switch (cmd) {
        case JOY_CMD_RESET:
            UPDATE_REG(COMM_JOYCNT, READ16LE(&ioMem[COMM_JOYCNT]) | JOYCNT_RESET);
        case JOY_CMD_STATUS:
            resp.push_back(0x00); // GBA device ID
            resp.push_back(0x04);
            break;

        case JOY_CMD_READ:
            resp.push_back((u8)(READ16LE(&ioMem[COMM_JOY_TRANS_L]) & 0xff));
            resp.push_back((u8)(READ16LE(&ioMem[COMM_JOY_TRANS_L]) >> 8));
            resp.push_back((u8)(READ16LE(&ioMem[COMM_JOY_TRANS_H]) & 0xff));
            resp.push_back((u8)(READ16LE(&ioMem[COMM_JOY_TRANS_H]) >> 8));
            UPDATE_REG(COMM_JOYSTAT, READ16LE(&ioMem[COMM_JOYSTAT]) & ~JOYSTAT_SEND); //mark it as sent
            UPDATE_REG(COMM_JOYCNT, READ16LE(&ioMem[COMM_JOYCNT]) | JOYCNT_SEND_COMPLETE);
            break;

        case JOY_CMD_WRITE:
            UPDATE_REG(COMM_JOY_RECV_L, (u16)((u16)data[2] << 8) | (u8)data[1]);
            UPDATE_REG(COMM_JOY_RECV_H, (u16)((u16)data[4] << 8) | (u8)data[3]);
            UPDATE_REG(COMM_JOYSTAT, READ16LE(&ioMem[COMM_JOYSTAT]) | JOYSTAT_RECV); //mark it as unread
            UPDATE_REG(COMM_JOYCNT, READ16LE(&ioMem[COMM_JOYCNT]) | JOYCNT_RECV_COMPLETE);
            break;

        default:
            return; // ignore
        }

        resp.push_back((u8)READ16LE(&ioMem[COMM_JOYSTAT]));
        dol->Send(resp);

        // Generate SIO interrupt if we can
        if ( ((cmd == JOY_CMD_RESET) || (cmd == JOY_CMD_READ) || (cmd == JOY_CMD_WRITE))
            && (READ16LE(&ioMem[COMM_JOYCNT]) & JOYCNT_INT_ENABLE) )
        {
            IF |= 0x80;
            UPDATE_REG(0x202, IF);
        }
        }
    }
}

void JoyBusUpdate(int ticks)
{
	linktime += ticks;
	//static int lastjoybusupdate = 0;
	//static u32 lasttm = 0;
	
	if (!ioMem) return;
	//if (!(DISPSTAT & 3)) return; //not in V/H-Blank
	if (reg[14].I==0x138 || reg[14].I==0x250 || reg[13].I>0x03007F00) return; //inside IRQ handler (0x138 w/ BIOS, 0x250 w/o BIOS)
	if (dol && !dol->connected) JoyBusShutdown();
	if (gba_link_auto) {
		if (!dol || !dol->connected) JoyBusConnect(); //else //will cause lags when used in main thread
		if (!dol || !dol->connected) gba_joybus_enabled = false; //recheck whether previous attempt to connect failed of not
	}
	static char joybusdata[5] = {0x10, 0, 0, 0, 0}; // init with invalid cmd
	static char joybuslastcmd = 0x10;
	static char joybuslastcmd2 = 0x10;
	static int joybuscmdctr = 1;

	bool dataexisted = false;
	//if (gba_joybus_peek) 
	dataexisted = ((joybusdata[0]!=0x10) || ((gba_joybus_peek || !gba_multiboot_ready) && dol && dol->connected && dol->PeekCmd(joybusdata)));
	if ( !gba_joybus_peek || dataexisted ) { //(dol && dol->connected && /*dol->IsValid() &&*/ dol->IsDataExisted())

		static u8 joybuslastidx = 0; //0xff;
		u16 jst = READ16LE(&ioMem[COMM_JOYSTAT]);
		u8 idx = (jst & 0x10);
		bool ok = false;
		if (dataexisted) {
			if (((skipBios || !useBios) && !gba_multiboot_ready) && ((READ16LE(&ioMem[COMM_RCNT]) & 0xc000)==0xc000)) {
				ok = true;
				if (joybusdata[0]!=0x10) MBJoybus(joybusdata[0]);
				jst = READ16LE(&ioMem[COMM_JOYSTAT]);
			}
			if (/*(joybusdata[0]==JOY_CMD_READ && (!(jst & JOYSTAT_SEND) || ticks)) ||*/ (joybusdata[0]==JOY_CMD_WRITE && ((jst & JOYSTAT_RECV) /*|| (joybuslastidx==idx && idx!=0)*/)) ) return;
			if (gba_joybus_fast)
			if (joybusdata[0]==JOY_CMD_STATUS) ok = true;
		}
	// Kinda ugly hack to update joybus stuff intermittently
	//if (GetTickCount()-joybuslasttime>100) ok = true; //else //prevent GBA joybus to get timeout when not getting IRQ within 160ms
	if ((ok /*|| !ticks*/) && gba_multiboot_ready && (linktime-lastjoybusupdate)<256) return; //replying status(cmd 0x00) too fast may cause GameCube joybus to get timeout and try to reset joybus
	if (!ticks || ok || (linktime > lastjoybusupdate)) { // + 0x3000 //higher value = slower dolphin
		//if (linktime > lastjoybusupdate)
		lastjoybusupdate = linktime + joybusinterval; //0x80; //0x100; // + 0x3000 //higher value = slower dolphin
		//else lastjoybusupdate = linktime + 256; //272 //224 //2048

	u16 jct = READ16LE(&ioMem[COMM_JOYCNT]);
	u16 IE = READ16LE(&ioMem[0x200]);
	//if (ok || (((READ16LE(&ioMem[COMM_RCNT]) & 0xc000)==0xc000) && //SIO in JOYBUS mode
	    //(((jst & JOYSTAT_SEND) || !(jst & JOYSTAT_RECV)) && (jct & 0x40)) && //if GBA have unsent data OR previous data from GameCube already read
	//    (!(jct & 0x07))) /*&& !(READ16LE(&ioMem[0x202]) & 0x80)*/) //(((READ16LE(&ioMem[COMM_JOYCNT]) & 0x07)==0x00) || ((READ16LE(&ioMem[COMM_JOYCNT]) & JOYCNT_INT_ENABLE) && !(READ16LE(&ioMem[0x202]) & 0x80))) //IRQ Enabled
	if (ok || ((jct & 0x47)==0x40 && (!(IF & 0x80) || !(IE & 0x80)) && (READ16LE(&ioMem[COMM_RCNT]) & 0xc000)==0xc000))
	{ 

		if ((joybusdata[0]==JOY_CMD_STATUS) && (joybuscmdctr==3) && (joybuslastcmd2!=JOY_CMD_READ) && ((jst & 0xa)==0) /*&& gba_multiboot_ready*/ && (GetTickCount()-jbcmdlasttime<16)) {lastjoybusupdate = linktime + 256; return;} //prevent getting joybus reset cmd when receiving too many status cmd (while Gamecube game expecting a new data from GBA but didn't see any sign of it after several times checking the status)
	//u32 tm = GetTickCount();
	//while (((READ16LE(&ioMem[COMM_JOYCNT]) & JOYCNT_INT_ENABLE)||(READ16LE(&ioMem[COMM_JOYSTAT]) & JOYSTAT_SEND)) && !AppTerminated && dol && dol->connected && !dol->IsDataExisted() && (GetTickCount()-tm)<5000) SleepEx(1,true); //GBA want to send
	
	//if (dol && dol->connected && /*dol->IsValid() &&*/ dol->IsDataExisted()) //dol->IsValid() doesn't return TRUE even when the socket is readable (there is incomming data in recv buffer)
	//{
		//lasttm = tm;

		//if (!dol)
		//	JoyBusConnect();

		//if (GetTickCount()-joybuslasttime>107) UPDATE_REG(COMM_JOYSTAT, READ16LE(&ioMem[COMM_JOYSTAT]) | JOYSTAT_SEND); //faking new data to send to trigger command 0x14 thus prevent joybus getting timeout
		//if (((data[0]==JOY_CMD_READ) && !(jst & JOYSTAT_SEND)) || ((data[0]==JOY_CMD_WRITE) && (jst & JOYSTAT_RECV))) return;

		std::vector<char> resp;

		u8 cmd = dol->ReceiveCmd(joybusdata);
		if (cmd==joybuslastcmd) joybuscmdctr++; else joybuscmdctr = 1;
		/*if((skipBios || !useBios) && !gba_multiboot_ready) { //built-in multiboot handler
			MBJoybus(cmd);
		}*/
		joybuslastcmd = cmd;
		if (cmd!=JOY_CMD_STATUS) joybuslastcmd2 = cmd;
		switch (cmd) {
		case JOY_CMD_RESET:
			//UPDATE_REG(COMM_JOYSTAT, READ16LE(&ioMem[COMM_JOYSTAT]) & ~(JOYSTAT_SEND|JOYSTAT_RECV)); //0
			UPDATE_REG(COMM_JOYCNT, READ16LE(&ioMem[COMM_JOYCNT]) | JOYCNT_RESET);
			if (joybusinterval<30000) lastjoybusupdate = linktime + 30000; //giving more time for GBA to clean up on reset
		case JOY_CMD_STATUS:
			resp.push_back(0x00); // GBA device ID
			resp.push_back(0x04);
			//if(!(jst & JOYSTAT_SEND)) //if GBA not trying to send
			//jst |= JOYSTAT_RECV; //tells the otherside that GBA no new data in JOY_RECV reg so GBA can receive more data
			//jst &= ~JOYSTAT_SEND; //GBA no new data in JOY_TRANS reg
			break;
		
		case JOY_CMD_READ:
			resp.push_back((u8)(READ16LE(&ioMem[COMM_JOY_TRANS_L]) & 0xff));
			resp.push_back((u8)(READ16LE(&ioMem[COMM_JOY_TRANS_L]) >> 8));
			resp.push_back((u8)(READ16LE(&ioMem[COMM_JOY_TRANS_H]) & 0xff));
			resp.push_back((u8)(READ16LE(&ioMem[COMM_JOY_TRANS_H]) >> 8));
			UPDATE_REG(COMM_JOYSTAT, READ16LE(&ioMem[COMM_JOYSTAT]) & ~JOYSTAT_SEND); //JOYSTAT_RECV //mark it as sent
			//jst &= ~JOYSTAT_SEND;
			//jst |= JOYSTAT_RECV; //tells the otherside that GBA no new data in JOY_RECV reg so GBA can receive more data
			UPDATE_REG(COMM_JOYCNT, READ16LE(&ioMem[COMM_JOYCNT]) | JOYCNT_SEND_COMPLETE);
			//if (joybusinterval<1008) lastjoybusupdate = linktime + 1008;
			break;

		case JOY_CMD_WRITE:
			UPDATE_REG(COMM_JOY_RECV_L, (u16)((u16)joybusdata[2] << 8) | (u8)joybusdata[1]);
			UPDATE_REG(COMM_JOY_RECV_H, (u16)((u16)joybusdata[4] << 8) | (u8)joybusdata[3]);
			UPDATE_REG(COMM_JOYSTAT, READ16LE(&ioMem[COMM_JOYSTAT]) | JOYSTAT_RECV); //JOYSTAT_SEND //mark it as unread
			//jst |= JOYSTAT_RECV;
			UPDATE_REG(COMM_JOYCNT, READ16LE(&ioMem[COMM_JOYCNT]) | JOYCNT_RECV_COMPLETE);
			joybuslastidx = idx;
			//if (joybusinterval<8064) lastjoybusupdate = linktime + 8064;
			break;

		default:
			joybusdata[0] = 0x10;
			return; // ignore unknown cmd? //shouldn't it reply with something to prevent the otherside stuck waiting for reply data for infinity?
			//treating unknown cmd as status cmd? or just reply the joystat?
			//resp.push_back(0x00); // GBA device ID
			//resp.push_back(0x04);
		}

		//if(cmd==JOY_CMD_RESET)
		//dol->DiscardData(); //clear recv buffer to prevent it from being full
		
		//jst |= JOYSTAT_SEND;
		//jst &= ~JOYSTAT_RECV;

		resp.push_back((u8)/*jst*/READ16LE(&ioMem[COMM_JOYSTAT])); //if STAT=08 Dolphin will send 00/ff cmd, if STAT=18 then Dolphin send 14 cmd and STAT became 10, if Dolphin send 15 cmd then STAT=12/22/32
		dol->Send(resp);
		joybusdata[0] = 0x10;

		// Generate SIO interrupt if we can
		if ( ((cmd == JOY_CMD_RESET) || (cmd == JOY_CMD_READ) || (cmd == JOY_CMD_WRITE)) //IRQ only used for device reset command isn't?
			&& (READ16LE(&ioMem[COMM_JOYCNT]) & JOYCNT_INT_ENABLE) )
		{
			IF |= 0x80;
			UPDATE_REG(0x202, IF);
			joybuslasttime = GetTickCount();
		}

		if (gba_mb_needsentclear) {
			gba_mb_needsentclear = false;
			UPDATE_REG(COMM_JOYCNT, READ16LE(&ioMem[COMM_JOYCNT]) & 0xfff8);
			UPDATE_REG(COMM_JOYSTAT, READ16LE(&ioMem[COMM_JOYSTAT]) & 0xfff5);
		}

		jbcmdlasttime = GetTickCount();

		#ifdef GBA_LOGGING
			if(systemVerbose & (/*VERBOSE_SIO |*/ VERBOSE_LINK)) {
				CString st = "";
				if (cmd==JOY_CMD_WRITE) st = DataHex((char*)&ioMem[COMM_JOY_RECV_L],4); else
				if (cmd==JOY_CMD_READ) st = DataHex((char*)&ioMem[COMM_JOY_TRANS_L],4);
				/*st = st + "- " + DataHex((char*)&internalRAM[0x58],4);
				st = st + "- " + DataHex((char*)&internalRAM[0x0c],4);
				st = st + "- " + DataHex((char*)&internalRAM[0x10],4);*/
				log("%d : JoyBus CMD:%02X [%d] Stat:%04X %04X %04X %04X  %s\n",GetTickCount(), cmd, joybuscmdctr, IE, IF, jct, jst, st);
			}
		#endif
	//}
	} //else lastjoybusupdate = linktime + 256; //else if(dol) dol->DiscardData();
	}
	}
}

#ifdef _MSC_VER

bool LinkRFUUpdate()
{
	//Network
	if(IsLinkConnected()/*lanlink.connected*/) { //synchronize RFU buffers as necessary to reduce network traffic? (update buffer with incoming data, send new data to other GBAs)
	 
	}

	if(!lanlink.active || rfu_enabled) { //Single Comp, RFU also uses memorymapped file as buffer to reduce network traffic on repeated identical data
		if (transfer && rfu_transfer_end <= 0) //this is to prevent continuosly sending & receiving data too fast which will cause the game unable to update the screen (the screen will looks freezed) due to miscommunication
		{
			if(rfu_waiting) {
				bool ok = false;
				u8 oldcmd = rfu_cmd;
				u8 oldq = linkmem->rfu_q[vbaid]; //linkmem->rfu_qlist[vbaid][linkmem->rfu_listfront[vbaid]]; //
				u32 tmout = linktimeout;
				if((!lanlink.active && speedhack)||(lanlink.speed && IsLinkConnected()/*lanlink.connected*/)) tmout = 16;
				//if(READ16LE(&ioMem[COMM_SIOCNT]) & 0x80) //needed? is this the cause of error when trying to battle for the 2nd time in union room(siocnt = 5003 instead of 5086 when waiting for 0x28 from 0xa5)? OR was it due to left over data?
				if(rfu_state!=RFU_INIT) //not needed?
				if(rfu_cmd == 0x24 || rfu_cmd == 0x25 || rfu_cmd == 0x35) {
					c_s.Lock();
					ok = /*gbaid!=vbaid* &&*/ linkmem->rfu_signal[vbaid] && linkmem->rfu_q[vbaid]>1 && rfu_qsend>1 /*&& linkmem->rfu_q[vbaid]>rfu_qsend*/;
					c_s.Unlock();
					if(ok && (GetTickCount()-rfu_lasttime)</*1000*/(DWORD)linktimeout) {/*rfu_transfer_end = 256;*/ return false;}
					if(linkmem->rfu_q[vbaid]<2 || rfu_qsend>1 /*|| linkmem->rfu_q[vbaid]<=rfu_qsend*/) 
					{
						rfu_cansend = true;
						c_s.Lock();
						linkmem->rfu_q[vbaid] = 0; //rfu_qsend;
						linkmem->rfu_qid[vbaid] = 0; //
						c_s.Unlock();
					}
					rfu_buf = 0x80000000;
				} else {
				if(((rfu_cmd == 0x11 || rfu_cmd==0x1a || rfu_cmd==0x26) && (GetTickCount()-rfu_lasttime)<16) || ((rfu_cmd==0xa5 || rfu_cmd==0xb5) && (GetTickCount()-rfu_lasttime)<tmout) || ((rfu_cmd==0xa7 || rfu_cmd==0xb7 /*|| (rfu_lastcmd2==0x24 && rfu_cmd==0x26)*/) && (GetTickCount()-rfu_lasttime)</*1000*/(DWORD)linktimeout)) { //
					//ok = false;
					//if (linkmem->rfu_q[vbaid]<2 /*|| (linkmem->rfu_request[vbaid] && linkmem->rfu_qid[vbaid]!=linkmem->rfu_request[vbaid])*/) //make sure previously sent data have been received
					c_s.Lock();
					ok = (!DATALIST.empty() || (linkmem->rfu_listfront[vbaid]!=linkmem->rfu_listback[vbaid]));
					c_s.Unlock();
					if(!ok)
					for(int i=0; i<linkmem->numgbas; i++)
					if (i!=vbaid)
						if (linkmem->rfu_q[i] && (linkmem->rfu_qid[i]&(1<<vbaid))) {ok = true; break;} //wait for reply
					if(/*vbaid==gbaid ||*/ !linkmem->rfu_signal[vbaid]) ok = true;
					if(!ok) {/*rfu_transfer_end = 256;*/ return false;}
				}
				if(rfu_cmd==0xa5 || rfu_cmd==0xa7 || rfu_cmd==0xb5 || rfu_cmd==0xb7 || rfu_cmd==0xee) rfu_polarity = 1;
				//rfu_polarity = 1; //reverse polarity to make the game send 0x80000000 command word (to be replied with 0x99660028 later by the adapter)
				if(rfu_cmd==0xa5 || rfu_cmd==0xa7) rfu_cmd = 0x28; else 
				if(rfu_cmd==0xb5 || rfu_cmd==0xb7) rfu_cmd = 0x36;
				if(READ32LE(&ioMem[COMM_SIODATA32_L])==0x80000000) rfu_buf = 0x99660000|(rfu_qrecv<<8)|rfu_cmd; else rfu_buf = 0x80000000;
				}
						
				#ifdef GBA_LOGGING
					if(systemVerbose & VERBOSE_LINK) {
						if((GetTickCount()-rfu_lasttime)>=/*tmout*/(DWORD)linktimeout)
						log("%08X : TimeOut[%02X] Old:%d New:%d\n", GetTickCount(), oldcmd, oldq, rfu_qsend);
						log("%08X : DoneWaiting[%02X] %08X -> %08X  [%04X, %d, %d]\n", GetTickCount(), oldcmd, READ32LE(&ioMem[COMM_SIODATA32_L]), rfu_buf, READ16LE(&ioMem[COMM_SIOCNT]), rfu_state, rfu_waiting);
						if(rfu_cansend && oldq>1 && (rfu_cmd==0x24 || rfu_cmd==0x24 || rfu_cmd==0x25 || rfu_cmd==0x35))
						log("%08X : OverrideSend[%02X] Old:%d New:%d\n", GetTickCount(), oldcmd, oldq, rfu_qsend);
					}
				#endif
						
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
	} 
	return true;
}

void LinkUpdate2(int ticks, int FrameCnt) //It seems Frameskipping on Client side causes instability, Client may need to execute the CPU slower than Server to maintain stability for some games (such as Mario Kart)
{
	char inbuffer[8192], outbuffer[8192];
	u16 *u16inbuffer = (u16*)inbuffer;
	u16 *u16outbuffer = (u16*)outbuffer;
	unsigned long notblock = 0; //AdamN: 0=blocking, non-zero=non-blocking
	BOOL disable = true;
	unsigned long arg = 0;
	BOOL recvd = false;
	BOOL sent = false;
	fd_set fdset;
	timeval wsocktimeout;
	
	if (ioMem == NULL)
		return;

	linktime += ticks;

	int missed = 0;
	int stacked = 0;
	static int misctr = 0;

	//if(ticks!=0 && linktime<1008) return;

	/*if (rfu_enabled)
	{
		linktime2 += ticks; // linktime2 is unused!
		rfu_transfer_end -= ticks;
		if (transfer && rfu_transfer_end <= 0) 
		{
			transfer = 0;
			if (READ16LE(&ioMem[COMM_SIOCNT]) & 0x4000) //IRQ Enable
			{
				IF |= 0x80; //Serial Communication
				UPDATE_REG(0x202, IF); //Interrupt Request Flags / IRQ Acknowledge
			}
			UPDATE_REG(COMM_SIOCNT, READ16LE(&ioMem[COMM_SIOCNT]) & 0xff7f);
		}
		return;
	}*/

	if (rfu_enabled)
	{
		linktime2 += ticks; // linktime2 is unused!
		rfu_transfer_end -= ticks;
		
		LinkRFUUpdate();

		if (transfer && rfu_transfer_end <= 0) 
		{
			transfer = 0;
			if (READ16LE(&ioMem[COMM_SIOCNT]) & 0x4000)
			{
				IF |= 0x80;
				UPDATE_REG(0x202, IF);
			}
			UPDATE_REG(COMM_SIOCNT, READ16LE(&ioMem[COMM_SIOCNT]) & 0xff7f); //Start bit.7 reset
			#ifdef GBA_LOGGING
				if(systemVerbose & VERBOSE_SIO) {
					log("SIOn32 : %04X %04X  %08X  (VCOUNT = %d) %d %d\n", READ16LE(&ioMem[COMM_RCNT]), READ16LE(&ioMem[COMM_SIOCNT]), READ32LE(&ioMem[COMM_SIODATA32_L]), VCOUNT, GetTickCount(), linktime2 );
				}
			#endif
		}
		return;
	}

	if(GetSIOMode(READ16LE(&ioMem[COMM_SIOCNT]), READ16LE(&ioMem[COMM_RCNT]))!=MULTIPLAYER) return;

	if (lanlink.active) //On Networks
	{
		if (IsLinkConnected()/*lanlink.connected*/)
		{
			int numbytes = 0;
			u16 siocnt = READ16LE(&ioMem[COMM_SIOCNT]);
			u16 rcnt = READ16LE(&ioMem[COMM_RCNT]);
			if(GetSIOMode(siocnt, rcnt)!=MULTIPLAYER) {/*UPDATE_REG(0x06, VCOUNT);*/ return;} //AdamN: skip if it's not MP mode, default mode at startup is Normal8bit
			if (linkid) { //Slave/Client?
				UPDATE_REG(COMM_SIOCNT, siocnt | 0x000c); //AdamN: set Bit.2(SI) and Bit.3(SD) to mark it as Ready
				//if(linktime<159/*1008*/) return; //AdamN: checking scanlines? giving delays to prevent too much slowdown, could cause instability?
				//linktime=0;
				//if(VCOUNT>160) UPDATE_REG(0x06, 160); //AdamN: forcing VCOUNT value to trick games that expect data exchange when VCOUNT=160
				//UPDATE_REG(COMM_SIOCNT, siocnt | 0x000c);
				//if(GetSIOMode(siocnt, rcnt)!=MULTIPLAYER) return; //AdamN: skip if it's not MP mode
				/*u16outbuffer[0] = 0;
				u16outbuffer[1] = 0;
				notblock = 1;
				ioctlsocket(lanlink.tcpsocket, FIONBIO, &notblock); //AdamN: temporarily use non-blocking for sending
				setsockopt(lanlink.tcpsocket, IPPROTO_TCP, TCP_NODELAY, (char*)&disable, sizeof(BOOL)); //true=send packet immediately
				sent=(send(lanlink.tcpsocket, outbuffer, 4, 0)>=0);*/ //AdamN: sending dummies packet to prevent timeout when server tried to read socket w/ an empty buffer
				notblock = 0;
				ioctlsocket(lanlink.tcpsocket, FIONBIO, &notblock); //AdamN: temporarily use blocking for reading
				int ern=errno; //errno;
				if(ern!=0) log("IOCTL1 Error: %d\n",ern);
				if(linkdatarecvd[0] /*|| VCOUNT>=159 || !LinkFirstTime*/) {
					bool last = true;
					for(int i=1;i<=lanlink.numgbas;i++) last&=linkdatarecvd[i];
					if(!last) {
						/*fdset.fd_count = 1;
						fdset.fd_array[0] = lanlink.tcpsocket;
						wsocktimeout.tv_sec = linktimeout / 1000;
						wsocktimeout.tv_usec = linktimeout % 1000; //0; //AdamN: remainder should be set also isn't?
						if(select(0, &fdset, NULL, NULL, &wsocktimeout)<=0) { //AdamN: this will blocks executions but allows Server to be paused w/o causing disconnection on Client
							int ern=errno;
							if(ern!=0) {
								lanlink.connected = false;
								log("%sCR[%d]\n",(LPCTSTR)LogStr,ern);
							}
							return;
						}*/
						if(!lc.WaitForData(linktimeout/*-1*/)) return;
					}
				}
				do {
				arg = lc.IsDataReady(); //0;
				/*if(ioctlsocket(lanlink.tcpsocket, FIONREAD, &arg)!=0) { //AdamN: Alternative(Faster) to Select(Slower)
					int ern=errno; 
					if(ern!=0) {
						log("%sCC Error: %d\n",(LPCTSTR)LogStr,ern);
						lanlink.connected = false;
						MessageBox(NULL, _T("Player 1 disconnected."), _T("Link"), MB_OK);
					}
				}*/
				if(arg>0) {
					stacked++;
					//UPDATE_REG(COMM_SIOCNT, READ16LE(&ioMem[COMM_SIOCNT]) | 0x000c); //AdamN: set Bit.2(SI) and Bit.3(SD) to mark it as Ready
					numbytes = 0;
					int sz=recv(lanlink.tcpsocket, inbuffer, 1, 0); //AdamN: read the size of packet
					int ern=errno; //errno;
					if(ern!=0) {
						if(ern==ECONNRESET || ern==ECONNABORTED || ern==10057 || ern==10051 || ern==10050 || ern==10065) LinkConnected(false);
						#ifdef GBA_LOGGING
							if(ern!=10060)
							if(systemVerbose & VERBOSE_LINK) {
								log("%sCRecv1 Error: %d\n",(LPCTSTR)LogStr,ern); //oftenly gets access violation if App closed down, could be due to LogStr=""
							}
						#endif
					}
					if(sz > 0) {
						sz = inbuffer[0];
						/*if(sz==0) 
							tmpctr++;*/
						UPDATE_REG(COMM_RCNT, READ16LE(&ioMem[COMM_RCNT]) & 0xfffe); //AdamN: LOWering bit.0 (SC)
						UPDATE_REG(COMM_SIOCNT, READ16LE(&ioMem[COMM_SIOCNT]) | 0x0080); //AdamN: Activate bit.7 (Start/Busy)
						numbytes++;
					}
					while(numbytes<sz) {
						int cnt=recv(lanlink.tcpsocket, inbuffer+numbytes, (sz-numbytes), 0); 
						int ern=errno; //errno; //AdamN: it seems WSAGetLastError can still gets 0 even when server no longer existed
						if(ern!=0 || cnt<=0) {
							log("%sCRecv2 Error: %d\n",(LPCTSTR)LogStr,ern);
							if(ern==10054 || ern==10053 || ern==10057 || ern==10051 || ern==10050 || ern==10065 || cnt<=0) LinkConnected(false);
							break;
						} else
						numbytes+=cnt;
					}
					recvd=(numbytes>1);
					//done: check sender id and update linkdata+register
					if(recvd) {
						#ifdef GBA_LOGGING
							if(systemVerbose & VERBOSE_LINK) {
								log("%sCRecv2 Size : %d  %s\n", (LPCTSTR)LogStr, numbytes, (LPCTSTR)DataHex(inbuffer,numbytes));
							}
						#endif
						int sid = inbuffer[1]; //AdamN: sender ID
						if(!sid) { //AdamN: if sender is parent then it's new cycle
							for(int i=1; i<=lanlink.numgbas; i++) linkdatarecvd[i] = false;
							WRITE32LE(&linkdata[0], 0xffffffff);
							WRITE32LE(&linkdata[2], 0xffffffff);
							WRITE32LE(&ioMem[COMM_SIOMULTI0], 0xffffffff); //AdamN: data from SIOMULTI0 & SIOMULTI1
							WRITE32LE(&ioMem[COMM_SIOMULTI2], 0xffffffff); //AdamN: data from SIOMULTI2 & SIOMULTI3
						}
						linkdata[sid] = u16inbuffer[1]; //AdamN: received data, u16inbuffer[1] points to inbuffer[2]
						linkdatarecvd[sid] = true;
						LinkFirstTime = false;
						//UPDATE_REG(0x06, VCOUNT); //AdamN: restore to the real VCOUNT, may be it shouldn't be restored until no longer in MP mode?
						UPDATE_REG((sid << 1)+COMM_SIOMULTI0, linkdata[sid]); //AdamN: SIOMULTI0 (16bit data received from master/server)
						UPDATE_REG(COMM_SIOCNT, (READ16LE(&ioMem[COMM_SIOCNT]) & 0xffcf) | (linkid << 4)); //AdamN: Set ID bit.4-5
						//UPDATE_REG(COMM_SIOCNT, READ16LE(&ioMem[COMM_SIOCNT]) & 0xff7f); //AdamN: Deactivate bit.7 (Start/Busy), should be done after a cycle finished
						//value &= 0xff7f; 
						//value |= (sent != 0) << 7;
						//done: if (sid<linkid)and(linkdata[linkid]/COMM_SIOMLT_SEND!=COMM_SIOMULTI[linkid] or COMM_SIOMULTI[linkid]==FFFF) then pass linkdata[linkid] to server to broadcast to the other GBAs
						sent = false;
						if(sid<linkid) { //AdamN: todo:need to check if client's program initiate transfer by through StartLink so this section doesn't needed
							linkdata[linkid] = READ16LE(&ioMem[COMM_SIOMLT_SEND]);
							if(/*linkdata[linkid] != READ16LE(&ioMem[(linkid << 1)+COMM_SIOMULTI0])*/!linkdatarecvd[linkid]) { //AdamN: if it's already send it's data on this cycle then don't send again
								outbuffer[0] = 4; //3; //AdamN: size of packet
								outbuffer[1] = linkid; //AdamN: Sender ID
								u16outbuffer[1] = linkdata[linkid];
								UPDATE_REG(COMM_RCNT, READ16LE(&ioMem[COMM_RCNT]) & 0xfffb); //AdamN: LOWering SI bit.2 (RCNT or SIOCNT?)
								notblock = 0; //1
								ioctlsocket(lanlink.tcpsocket, FIONBIO, &notblock); //AdamN: temporarily use non-blocking for sending
								int ern=errno; //errno;
								if(ern!=0) log("IOCTL11 Error: %d\n",ern);
								#ifdef GBA_LOGGING
									if(systemVerbose & VERBOSE_LINK) {
										log("%sCSend-0 Size : %d  %s\n", (LPCTSTR)LogStr, 4, (LPCTSTR)DataHex(outbuffer,4));
									}
								#endif
								setsockopt(lanlink.tcpsocket, IPPROTO_TCP, TCP_NODELAY, (char*)&disable, sizeof(BOOL)); //true=send packet immediately
								sent=(send(lanlink.tcpsocket, outbuffer, 4, 0)>=0);
								ern=errno;
								if(ern!=0) {
									log("Send-0 Error: %d\n",ern); //AdamN: might be getting err 10035(would block) when used on non-blocking socket
									if(ern==10054 || ern==10053 || ern==10057 || ern==10051 || ern==10050 || ern==10065) LinkConnected(false);
								}
								if(sent) {
									UPDATE_REG((linkid << 1)+COMM_SIOMULTI0, linkdata[linkid]);
									//UPDATE_REG(COMM_RCNT, READ16LE(&ioMem[COMM_RCNT]) & 0xfff7); //AdamN: LOWering SO bit.3 (RCNT or SIOCNT?)
									linkdatarecvd[linkid] = true;
								}
							}
						}
						bool last = true;
						for(int i=0; i<=lanlink.numgbas; i++) last &= linkdatarecvd[i];
						if(last) { //AdamN: cycle ends
							//UPDATE_REG(COMM_RCNT, READ16LE(&ioMem[COMM_RCNT]) | 0x0001); //AdamN: HIGHering bit.0 (SC), only needed for Master/Server?
							//UPDATE_REG(COMM_RCNT, READ16LE(&ioMem[COMM_RCNT]) | 0x0008); //AdamN: HIGHering SO bit.3 (RCNT or SIOCNT?)
							UPDATE_REG(COMM_RCNT, READ16LE(&ioMem[COMM_RCNT]) | 0x0007/*f*/); //AdamN: HIGHering SC,SD,SI,SO (apparently SD and SI need to be High also for Slave), Slave might be checking SC when not using IRQ
							UPDATE_REG(COMM_SIOCNT, READ16LE(&ioMem[COMM_SIOCNT]) & 0xff7f); //AdamN: Deactivate bit.7 (Start/Busy)
							//AdamN: Trigger Interrupt if Enabled
							if (READ16LE(&ioMem[COMM_SIOCNT]) & 0x4000) { //IRQ Enable
								IF |= 0x80; //Serial Communication
								UPDATE_REG(0x202, IF); //Interrupt Request Flags / IRQ Acknowledge
							}
							for(int i=0; i<=lanlink.numgbas; i++) linkdatarecvd[i]=false; //AdamN: does it need to reset these?
							#ifdef GBA_LOGGING
								if(systemVerbose & VERBOSE_SIO) {
									//if(((READ16LE(&ioMem[COMM_SIOCNT]) >> 4) & 3) != linkid)
									//if(READ16LE(&ioMem[COMM_SIOCNT]) & 0x4000)
									log("SIO : %04X %04X  %04X %04X %04X %04X  (VCOUNT = %d) %d\n", READ16LE(&ioMem[COMM_RCNT]), READ16LE(&ioMem[COMM_SIOCNT]), READ16LE(&ioMem[COMM_SIOMULTI0]), READ16LE(&ioMem[COMM_SIOMULTI1]), READ16LE(&ioMem[COMM_SIOMULTI2]), READ16LE(&ioMem[COMM_SIOMULTI3]), VCOUNT, GetTickCount() );
								}
							#endif
							break; //to exit while(arg>0 && lanlink.connected); if it's last
						} else if(sent) UPDATE_REG(COMM_RCNT, READ16LE(&ioMem[COMM_RCNT]) & 0xfff7); //AdamN: LOWering SO bit.3 (RCNT or SIOCNT?)
						//if(sent) UPDATE_REG(COMM_RCNT, 7); //AdamN: Bit.0-2 (SC,SD,SI) as for GP
					}
				} else missed++;
				} while(arg>0 && IsLinkConnected()/*lanlink.connected*/);
				UPDATE_REG(COMM_SIOCNT, (READ16LE(&ioMem[COMM_SIOCNT]) & 0xffcf) | (linkid << 4)); //AdamN: Set ID bit.4-5, needed for Mario Kart
				//UPDATE_REG(COMM_SIOCNT, READ16LE(&ioMem[COMM_SIOCNT]) & 0xff77); //AdamN: making it not ready so slave doesn't start counting the in-game timeout counter
				//if(!LinkFirstTime) {
				//lc.WaitForData(1);
				//if(misctr++<400)
				//	log("Frame:%d Tick:%d Missed:%d Stacked:%d\n",FrameCnt,/*GetTickCount()*/ticks,missed,stacked);
				//}
				/*notblock = 1;
				ioctlsocket(lanlink.tcpsocket, FIONBIO, &notblock); //AdamN: back to non-blocking, might not be needed
				int ern=errno;
				if(ern!=0) log("IOCTL2 Error: %d\n",ern);*/

			} else { //Server/Master?
				UPDATE_REG(COMM_SIOCNT, siocnt | 0x0008); //AdamN: set Bit.2(SI) and Bit.3(SD) to mark it as Ready
				//if(linktime<2) return; //AdamN: giving delays to prevent too much slowdown, but could cause instability
				//linktime=0;
				//if(GetSIOMode(siocnt, rcnt)!=MULTIPLAYER) return; //AdamN: skip if it's not MP mode
				/*sent = false;
				u16outbuffer[0] = 0;
				u16outbuffer[1] = 0;
				notblock = 1;
				for(int i=1;i<=lanlink.numgbas;i++) {
					ioctlsocket(ls.tcpsocket[i], FIONBIO, &notblock); //AdamN: temporarily use non-blocking for sending multiple data at once
					setsockopt(ls.tcpsocket[i], IPPROTO_TCP, TCP_NODELAY, (char*)&disable, sizeof(BOOL)); //true=send packet immediately
					sent|=(send(ls.tcpsocket[i], outbuffer, 1, 0)>=0); //AdamN: sending dummies packet to prevent timeout when client tried to read socket w/ an empty buffer
				}*/
				if(!linkdatarecvd[0]) return; //AdamN: don't read if it's not starting a cycle yet
				bool last = true;
				int ready = 0;
				for(int i=1;i<=lanlink.numgbas;i++) last&=linkdatarecvd[i];
				if(!last) {
				//FD_ZERO(&fdset);
				//FD_SET(ls.tcpsocket[i], &fdset);
				fdset.fd_count = lanlink.numgbas; //not lanlink.numgbas+1; since it's started form 1 instead of 0
				notblock = 0;
				for(int i=1; i<=lanlink.numgbas; i++) {
					fdset.fd_array[i-1] = ls.tcpsocket[i];
					ioctlsocket(ls.tcpsocket[i], FIONBIO, &notblock); //AdamN: temporarily use blocking for reading
					int ern=errno; //errno;
					if(ern!=0) log("IOCTL30 Error: %d\n",ern);
				}
				wsocktimeout.tv_sec = linktimeout / 1000;
				wsocktimeout.tv_usec = linktimeout % 1000; //0; //AdamN: remainder should be set also isn't?
				ready = select(0, &fdset, NULL, NULL, &wsocktimeout); //AdamN: this will blocks executions but allows Client to be paused w/o causing disconnection on Server
				if(ready<=0){ //AdamN: may cause noticible delay, result can also be SOCKET_ERROR, Select seems to be needed to maintain stability
					int ern=errno; //may gets error 10038 (invalid socket handle) when using non-blocking sockets
					if(ern!=0) {
						LinkConnected(false);
						log("%sCR[%d]\n",(LPCTSTR)LogStr,ern);
					}
					return;
				}
				}
				if(ready>0)
				do {
				for(int i=1; i<=lanlink.numgbas; i++) {
					notblock = 0;
					ioctlsocket(ls.tcpsocket[i], FIONBIO, &notblock); //AdamN: temporarily use blocking for reading
					int ern=errno; //errno;
					if(ern!=0) log("IOCTL3 Error: %d\n",ern);
					/*fdset.fd_count = 1;
					fdset.fd_array[0] = ls.tcpsocket[i];
					wsocktimeout.tv_sec = linktimeout / 1000;
					wsocktimeout.tv_usec = linktimeout % 1000; //0; //AdamN: remainder should be set also isn't?
					if(select(0, &fdset, NULL, NULL, &wsocktimeout)<=0){ //AdamN: may cause noticible delay, result can also be SOCKET_ERROR, Select seems to be needed to maintain stability
						int ern=errno;
						if(ern!=0) {
							lanlink.connected = false;
							log("%sCR%d[%d]\n",(LPCTSTR)LogStr,i,ern);
						}
						return;
					}*/
					arg = 0;
					if(ioctlsocket(ls.tcpsocket[i], FIONREAD, &arg)!=0) {
						int ern=errno; //AdamN: this seems to get ern=10038(invalid socket handle) often
						if(ern!=0) {
							log("%sSR-%d[%d]\n",(LPCTSTR)LogStr,i,ern);
							char message[40];
							LinkConnected(false);
							sprintf(message, _T("Client %d disconnected."), i);
							MessageBox(NULL, message, _T("Link"), MB_OK);
							break;
						}
						continue; //break;
					}
					if(arg>0) {
						numbytes = 0;
						int sz=recv(ls.tcpsocket[i], inbuffer, 1, 0); //AdamN: read the size of packet
						int ern=errno;
						if(ern!=0) {
							if(ern==10054 || ern==10053 || ern==10057 || ern==10051 || ern==10050 || ern==10065) LinkConnected(false);
							#ifdef GBA_LOGGING
								if(ern!=10060)
								if(systemVerbose & VERBOSE_LINK) { 
									log("%sSRecv1-%d Error: %d\n",(LPCTSTR)LogStr,i,ern);
								}
							#endif
						}
						if(sz > 0) {
							sz = inbuffer[0];
							UPDATE_REG(COMM_RCNT, READ16LE(&ioMem[COMM_RCNT]) & 0xfffe); //AdamN: LOWering bit.0 (SC), not really needed here
							UPDATE_REG(COMM_SIOCNT, READ16LE(&ioMem[COMM_SIOCNT]) | 0x0080); //AdamN: Activate bit.7 (Start/Busy), not really needed here
							numbytes++;
						}
						while(numbytes<sz) {
							int cnt=recv(ls.tcpsocket[i], inbuffer+numbytes, (sz-numbytes), 0);
							int ern=errno;
							if(ern!=0 || cnt<=0) {
								log("%sSRecv2-%d Error: %d\n",(LPCTSTR)LogStr,i,ern);
								if(ern==10054 || ern==10053 || ern==10057 || ern==10051 || ern==10050 || ern==10065 || cnt<=0) LinkConnected(false);
								break;
							} else
							numbytes+=cnt;
						}
						recvd=(numbytes>1);
						//done: check sender id and update linkdata+register
						if(recvd) {
							#ifdef GBA_LOGGING
								if(systemVerbose & VERBOSE_LINK) {
									log("%sSRecv2 Size : %d  %s\n", (LPCTSTR)LogStr, numbytes, (LPCTSTR)DataHex(inbuffer,numbytes));
								}
							#endif
							int sid = inbuffer[1]; //AdamN: sender ID
							linkdata[sid] = u16inbuffer[1]; //AdamN: received data, u16inbuffer[1] points to inbuffer[2]
							//if(!sid) //AdamN: if sender is parent then it's new cycle, not possible here
							//	for(int i=0; i<=lanlink.numgbas; i++) linkdatarecvd[i] = false;
							linkdatarecvd[sid] = true;
							UPDATE_REG((sid << 1)+COMM_SIOMULTI0, linkdata[sid]); //AdamN: SIOMULTI0 (16bit data received from master/server)
							//UPDATE_REG(COMM_SIOCNT, (READ16LE(&ioMem[COMM_SIOCNT]) & 0xffcf) | (linkid << 4)); //AdamN: Set ID bit.4-5 not needed for server as it's already set in StartLink
							//UPDATE_REG(COMM_SIOCNT, READ16LE(&ioMem[COMM_SIOCNT]) & 0xff7f); //AdamN: Deactivate bit.7 (Start/Busy), should be done after a cycle finished
							//value &= 0xff7f; 
							//value |= (sent != 0) << 7;
							//
							sent = false;
							//todo: Master: broadcast received data to other GBAs
							outbuffer[0] = 4; //3; //AdamN: size of packet
							outbuffer[1] = sid; //AdamN: Sender ID
							u16outbuffer[1] = linkdata[sid];
							for(int j=1; j<=lanlink.numgbas; j++)
							if(j!=i && j!=sid) {
								notblock = 0; //1
								ioctlsocket(ls.tcpsocket[j], FIONBIO, &notblock); //AdamN: temporarily use non-blocking for sending multiple data at once
								int ern=errno;
								if(ern!=0) log("IOCTL31 Error: %d\n",ern);
								#ifdef GBA_LOGGING
									if(systemVerbose & VERBOSE_LINK) {
										log("%sSSend1 to : %d  Size : %d  %s\n", (LPCTSTR)LogStr, j, 4, (LPCTSTR)DataHex(outbuffer,4));
									}
								#endif
								setsockopt(ls.tcpsocket[j], IPPROTO_TCP, TCP_NODELAY, (char*)&disable, sizeof(BOOL)); //true=send packet immediately
								sent|=(send(ls.tcpsocket[j], outbuffer, 4, 0)>=0);
								ern=errno;
								if(ern!=0) {
									log("Send-%d Error: %d\n",j,ern);
									if(ern==10054 || ern==10053 || ern==10057 || ern==10051 || ern==10050 || ern==10065) LinkConnected(false);
									if(!IsLinkConnected()/*lanlink.connected*/) break;
								}
								if(sent) {
									//UPDATE_REG((linkid << 1)+COMM_SIOMULTI0, linkdata[linkid]);
									//UPDATE_REG(COMM_RCNT, READ16LE(&ioMem[COMM_RCNT]) & 0xfff7); //AdamN: LOWering SO bit.3 (RCNT or SIOCNT?)
									linkdatarecvd[j] = true;
								}
							}
						}
					}
				}
				last = true;
				for(int i=0; i<=lanlink.numgbas; i++) last &= linkdatarecvd[i];
				if(last) { //AdamN: cycle ends
					//UPDATE_REG(COMM_RCNT, READ16LE(&ioMem[COMM_RCNT]) | 0x0001); //AdamN: HIGHering bit.0 (SC), only needed for Master/Server?
					//UPDATE_REG(COMM_RCNT, READ16LE(&ioMem[COMM_RCNT]) | 0x0009 /*8*/); //AdamN: HIGHering SO bit.3 (RCNT or SIOCNT?)
					UPDATE_REG(COMM_RCNT, READ16LE(&ioMem[COMM_RCNT]) | 0x0003/*b*/); //AdamN: HIGHering SC,SD,SO (apparently SD need to be High also for Master), Does Master checking SC when not using IRQ also?
					UPDATE_REG(COMM_SIOCNT, READ16LE(&ioMem[COMM_SIOCNT]) & 0xff7f); //AdamN: Deactivate bit.7 (Start/Busy)
					//AdamN: Trigger Interrupt if Enabled
					if (READ16LE(&ioMem[COMM_SIOCNT]) & 0x4000) { //IRQ Enable
						IF |= 0x80; //Serial Communication
						UPDATE_REG(0x202, IF); //Interrupt Request Flags / IRQ Acknowledge
					}
					for(int i=0; i<=lanlink.numgbas; i++) linkdatarecvd[i]=false; //AdamN: does it need to reset these?
					#ifdef GBA_LOGGING
						if(systemVerbose & VERBOSE_SIO) {
							//if(READ16LE(&ioMem[COMM_SIOCNT]) & 0x4000)
							log("SIO : %04X %04X  %04X %04X %04X %04X  (VCOUNT = %d) %d\n", READ16LE(&ioMem[COMM_RCNT]), READ16LE(&ioMem[COMM_SIOCNT]), READ16LE(&ioMem[COMM_SIOMULTI0]), READ16LE(&ioMem[COMM_SIOMULTI1]), READ16LE(&ioMem[COMM_SIOMULTI2]), READ16LE(&ioMem[COMM_SIOMULTI3]), VCOUNT, GetTickCount() );
						}
					#endif
				} else if(sent) UPDATE_REG(COMM_RCNT, READ16LE(&ioMem[COMM_RCNT]) & 0xfff7); //AdamN: LOWering SO bit.3 (RCNT or SIOCNT?)	
				} while(!last && IsLinkConnected()/*lanlink.connected*/);
				UPDATE_REG(COMM_SIOCNT, (READ16LE(&ioMem[COMM_SIOCNT]) & 0xffcf) | (linkid << 4)); //AdamN: Set ID bit.4-5, needed for Mario Kart
			}
		}
		return;
	} 
	return;
}

// Windows threading is within!
void LinkUpdate(int ticks)
{
	BOOL recvd = false;
	BOOL sent = false;
	linktime += ticks;

	if (rfu_enabled)
	{
		linktime2 += ticks; // linktime2 is unused!
		rfu_transfer_end -= ticks;
		
		//if(lanlink.active && lanlink.connected)
		if(LinkRFUUpdate())
		if (transfer && rfu_transfer_end <= 0) //this is to prevent continuosly sending & receiving data too fast which will cause the game unable to update the screen (the screen will looks freezed) due to miscommunication
		{
			transfer = 0;
			u16 value = READ16LE(&ioMem[COMM_SIOCNT]);
			if (value & 0x4000) //IRQ Enable
			{
				IF |= 0x80; //Serial Communication
				UPDATE_REG(0x202, IF); //Interrupt Request Flags / IRQ Acknowledge
			}

			//if (rfu_polarity) value ^= 4;
			value &= 0xfffb;
			value |= (value & 1)<<2; //this will automatically set the correct polarity, even w/o rfu_polarity since the game will be the one who change the polarity instead of the adapter

			UPDATE_REG(COMM_SIOCNT, (value & 0xff7f)|0x0008); //Start bit.7 reset, SO bit.3 set automatically upon transfer completion?
			#ifdef GBA_LOGGING
				if(systemVerbose & VERBOSE_SIO) {
					log("SIOn32 : %04X %04X  %08X  (VCOUNT = %d) %d %d\n", READ16LE(&ioMem[COMM_RCNT]), READ16LE(&ioMem[COMM_SIOCNT]), READ32LE(&ioMem[COMM_SIODATA32_L]), VCOUNT, GetTickCount(), linktime2 );
				}
			#endif
		}
		return;
	}

	//if(GetSIOMode(READ16LE(&ioMem[COMM_SIOCNT]), READ16LE(&ioMem[COMM_RCNT]))!=MULTIPLAYER) return; //may cause server to stop responding when client no longer in multiplayer mode

	if (lanlink.active) //On Networks
	{
		if (IsLinkConnected()/*lanlink.connected*/)
		{
			if (after) //related to speedhack?
			{
				if (linkid && linktime>6044) { //is this 6044 = max timeout?
					LogStrPush("LinkUpd1");
					recvd = lc.Recv(); //AdamN: not sure who need this, never reach here?
					LogStrPop(8);
					oncewait = true;
				}
				else
					return;
			}

			if (linkid && !transfer && lc.numtransfers>0 && linktime>=savedlinktime) //may cause an issue when linktime is integer type with too large time value?
			{
				linkdata[linkid] = READ16LE(&ioMem[COMM_SIODATA8]);

				if (!lc.oncesend) {
					LogStrPush("LinkUpd2");
					//DWORD tmpTime = GetTickCount();
					sent = lc.Send(); //AdamN: Client need to send this often, even when server is not(no longer) in multiplayer mode
					//log("Sending Time = %d\n", GetTickCount()-tmpTime);
					LogStrPop(8);
				}
				lc.oncesend = false;
				if(sent) { //AdamN: no need to check sent here ?
				UPDATE_REG(COMM_SIODATA32_L, linkdata[0]); //AdamN: linkdata[0] instead of linkdata[linkid]?
				UPDATE_REG(COMM_SIOCNT, READ16LE(&ioMem[COMM_SIOCNT]) | 0x80);
				transfer = 1;
				if (lc.numtransfers==1)
					linktime = 0;
				else
					linktime -= savedlinktime;
				}
			}

			if (transfer && lanlink.numgbas>0 && linktime>=trtimeend[lanlink.numgbas-1][tspeed]) //is this safe? as lanlink.numgbas is one less than the actual GBA instances
			{
				if (READ16LE(&ioMem[COMM_SIOCNT]) & 0x4000) //IRQ Enable
				{
					IF |= 0x80; //Serial Communication
					UPDATE_REG(0x202, IF); //Interrupt Request Flags / IRQ Acknowledge
				}

				UPDATE_REG(COMM_SIOCNT, (READ16LE(&ioMem[COMM_SIOCNT]) & 0xff0f) | (linkid << 4));
				transfer = 0;
				linktime -= trtimeend[lanlink.numgbas-1][tspeed];
				oncewait = false;

				if (!lanlink.speed) //lanlink.speed = speedhack
				{
					if (linkid) { //Slave/Client
						LogStrPush("LinkUpd3");
						recvd = lc.Recv(); //AdamN: Client need to read this often
											//recvd MUST be TRUE (need to receives data) inorder to maintain linking stability, may need to wait for incomming data
						LogStrPop(8);
					} else { //Master/Server
						LogStrPush("LinkUpd4");
						recvd = ls.Recv(); // WTF is the point of this?
					               //AdamN: This is often Needed for Server/Master to works properly, This seems also to be the cause of stop responding on server when a client closed down after connection established, but the infinite loop was occuring inside ls.Recv(); (fixed tho) however, timeouts inside ls.Recv() can still cause lag
									//recvd MUST be TRUE (need to receives data) inorder to maintain linking stability, may need to wait for incomming data
						LogStrPop(8);
					}
					if(recvd) {
					UPDATE_REG(COMM_SIODATA32_H, linkdata[1]); //0x122 //COMM_SIOMULTI1
					UPDATE_REG(COMM_SIOMULTI2, linkdata[2]); //0x124
					UPDATE_REG(COMM_SIOMULTI3, linkdata[3]); //0x126
					oncewait = true;
					#ifdef GBA_LOGGING
						if(systemVerbose & VERBOSE_SIO) {
							//if(((READ16LE(&ioMem[COMM_SIOCNT]) >> 4) & 3) != linkid)
							//if(READ16LE(&ioMem[COMM_SIOCNT]) & 0x4000)
							log("SIOm16 : %04X %04X  %04X %04X %04X %04X  (VCOUNT = %d) %d %d\n", READ16LE(&ioMem[COMM_RCNT]), READ16LE(&ioMem[COMM_SIOCNT]), READ16LE(&ioMem[COMM_SIOMULTI0]), READ16LE(&ioMem[COMM_SIOMULTI1]), READ16LE(&ioMem[COMM_SIOMULTI2]), READ16LE(&ioMem[COMM_SIOMULTI3]), VCOUNT, GetTickCount(), savedlinktime );
						}
					#endif
					}

				} else { //not speedhack
					if(recvd) { //AdamN: should this be checked for linkdata consistency?
					after = true;
					if (lanlink.numgbas >= 1) //(lanlink.numgbas == 1) //AdamN: only for 2 players?
					{
						UPDATE_REG(COMM_SIODATA32_H, linkdata[1]); //0x122 //COMM_SIOMULTI1
						UPDATE_REG(COMM_SIOMULTI2, linkdata[2]); //0x124
						UPDATE_REG(COMM_SIOMULTI3, linkdata[3]); //0x126
						#ifdef GBA_LOGGING
						if(systemVerbose & VERBOSE_SIO) {
							//if(((READ16LE(&ioMem[COMM_SIOCNT]) >> 4) & 3) != linkid)
							//if(READ16LE(&ioMem[COMM_SIOCNT]) & 0x4000)
							log("SIOm16 : %04X %04X  %04X %04X %04X %04X  (VCOUNT = %d) %d %d\n", READ16LE(&ioMem[COMM_RCNT]), READ16LE(&ioMem[COMM_SIOCNT]), READ16LE(&ioMem[COMM_SIOMULTI0]), READ16LE(&ioMem[COMM_SIOMULTI1]), READ16LE(&ioMem[COMM_SIOMULTI2]), READ16LE(&ioMem[COMM_SIOMULTI3]), VCOUNT, GetTickCount(), savedlinktime );
						}
						#endif
					}
					}
				}
			}
		}
		return;
	} 
	else { //Single Computer
	// ** CRASH ** linkmem is NULL, todo investigate why, added null check
	if (linkid && !transfer && linkmem && linktime >= linkmem->lastlinktime && linkmem->numtransfers) //On Single Computer (link.active=false)
	{
		linkmem->linkdata[linkid] = READ16LE(&ioMem[COMM_SIODATA8]);

		if (linkmem->numtransfers == 1)
		{
			linktime = 0;
			if (WaitForSingleObject(linksync[linkid], linktimeout) == WAIT_TIMEOUT)
				linkmem->numtransfers = 0;
		}
		else
			linktime -= linkmem->lastlinktime;

		switch ((linkmem->linkcmd[0]) >> 8)
		{
		case 'M':
			tspeed = (linkmem->linkcmd[0]) & 3;
			transfer = 1;
			WRITE32LE(&ioMem[COMM_SIODATA32_L], 0xffffffff);
			WRITE32LE(&ioMem[0x124], 0xffffffff); //COMM_SIOMULTI2
			UPDATE_REG(COMM_SIOCNT, READ16LE(&ioMem[COMM_SIOCNT]) | 0x80);
			break;
		}
	}

	if (!transfer)
		return;

	if (transfer && linktime>=trtimedata[transfer-1][tspeed] && transfer<=linkmem->numgbas)
	{
		if (transfer-linkid == 2)
		{
			SetEvent(linksync[linkid+1]);
			if (WaitForSingleObject(linksync[linkid], linktimeout) == WAIT_TIMEOUT)
				linkmem->numtransfers = 0;
			ResetEvent(linksync[linkid]);
		}

		UPDATE_REG(0x11e + (transfer<<1), linkmem->linkdata[transfer-1]);
		transfer++;
	}

	if (transfer && linktime>=trtimeend[linkmem->numgbas-2][tspeed])
	{
		if (linkid == linkmem->numgbas-1)
		{
			SetEvent(linksync[0]);
			if (WaitForSingleObject(linksync[linkid], linktimeout) == WAIT_TIMEOUT)
				linkmem->numtransfers = 0;

			ResetEvent(linksync[linkid]);
			
		}

		transfer = 0;
		linktime -= trtimeend[0][tspeed];
		if (READ16LE(&ioMem[COMM_SIOCNT]) & 0x4000)
		{
			IF |= 0x80;
			UPDATE_REG(0x202, IF);
		}
		UPDATE_REG(COMM_SIOCNT, (READ16LE(&ioMem[COMM_SIOCNT]) & 0xff0f) | (linkid << 4));
		linkmem->linkdata[linkid] = 0xffff;
	}
	}

	return;
}

inline int GetSIOMode(u16 siocnt, u16 rcnt)
{
	if (!(rcnt & 0x8000))
	{
		switch (siocnt & 0x3000) {
		case 0x0000: return NORMAL8; //used for GB/GBC Link ?
		case 0x1000: return NORMAL32; //used for GBA Wireless Link
		case 0x2000: return MULTIPLAYER; //AdamN: 16bit GBA Cable Link
		case 0x3000: return UART; //AdamN: 8bit
		}
	}else //AdamN: added ELSE to make sure bit.15 is 1 as there is no default case handler above

	if (rcnt & 0x4000) //AdamN: Joybus is (rcnt & 0xC000)==0xC000
		return JOYBUS;

	return GP; //AdamN: GeneralPurpose is (rcnt & 0xC000)==0x8000
}

u16 StartRFU4(u16 value)
{
	//TODO: Need to use c_s.Lock/Unlock when accessing shared variable, or use LinkHandlerThread during idle instead of in a different thread
	static char inbuffer[1036], outbuffer[1036];
	u16 *u16inbuffer = (u16*)inbuffer;
	u16 *u16outbuffer = (u16*)outbuffer;
	u32 *u32inbuffer = (u32*)inbuffer;
	u32 *u32outbuffer = (u32*)outbuffer;
	static int outsize, insize;

	static CString st = _T("");
	//static CString st2 = _T(""); //since st.Format can't use it's self (st) as argument we need another CString

	static bool logstartd;
	//MSG msg;
	u32 CurCOM = 0, CurDAT = 0;
	bool rfulogd = (READ16LE(&ioMem[COMM_SIOCNT])!=value);

	switch (GetSIOMode(value, READ16LE(&ioMem[COMM_RCNT]))) {
	case NORMAL8: //occurs after sending 0x996600A8 cmd
		rfu_polarity = 0;
		//log("RFU Wait : %04X  %04X  %d\n", READ16LE(&ioMem[COMM_RCNT]), READ16LE(&ioMem[COMM_SIOCNT]), GetTickCount() );
		return value;
		break;

	case NORMAL32:
		if (transfer) return value; //don't do anything if previous cmd aren't sent yet, may fix Boktai2 Not Detecting wireless adapter

		#ifdef GBA_LOGGING
			if(systemVerbose & VERBOSE_LINK) {
				if(!logstartd)
				if(rfulogd) {
					//log("%08X : %04X  ", GetTickCount(), value);
					st.Format(_T("%08X : %04X[%04X]"), GetTickCount(), value, READ16LE(&ioMem[COMM_SIOCNT]));
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

			u16 a = READ16LE(&ioMem[COMM_SIODATA32_H]);

			#ifdef GBA_LOGGING
				if(systemVerbose & VERBOSE_LINK) {
					if(rfulogd)
						st.AppendFormat(_T("    %08X"), READ32LE(&ioMem[COMM_SIODATA32_L])); else
					st.Format(_T("%08X : %04X[%04X]    %08X"), GetTickCount(), value, READ16LE(&ioMem[COMM_SIOCNT]), READ32LE(&ioMem[COMM_SIODATA32_L]));
					//st = st2;
					logstartd = true;
				}
			#endif

			switch (rfu_state) {
			case RFU_INIT:
				if (READ32LE(&ioMem[COMM_SIODATA32_L]) == 0xb0bb8001 /*|| READ32LE(&ioMem[COMM_SIODATA32_L]) == 0x7FFE8001 || READ32LE(&ioMem[COMM_SIODATA32_L]) == 0x80017FFE || READ32LE(&ioMem[COMM_SIODATA32_L]) == 0x8001B0BB*/) { //
					rfu_state = RFU_COMM;	// end of startup
					rfu_initialized = true;
					value &= 0xfffb; //0xff7b; //Bit.2 need to be 0 to indicate a finished initialization to fix MarioGolfAdv from occasionally Not Detecting wireless adapter (prevent it from sending 0x7FFE8001 comm)?
					rfu_polarity = 0; //not needed?
					//RFUClear();
				}
				rfu_buf = (READ16LE(&ioMem[COMM_SIODATA32_L])<<16)|a;
				break;

			case RFU_COMM:
				CurCOM = READ32LE(&ioMem[COMM_SIODATA32_L]);
				if (a == 0x9966) //initialize cmd
				{
					u8 tmpcmd = CurCOM;
					if(tmpcmd!=0x10 && tmpcmd!=0x11 && tmpcmd!=0x13 && tmpcmd!=0x14 && tmpcmd!=0x16 && tmpcmd!=0x17 && tmpcmd!=0x19 && tmpcmd!=0x1a && tmpcmd!=0x1b && tmpcmd!=0x1c && tmpcmd!=0x1d && tmpcmd!=0x1e && tmpcmd!=0x1f && tmpcmd!=0x20 && tmpcmd!=0x21 && tmpcmd!=0x24 && tmpcmd!=0x25 && tmpcmd!=0x26 && tmpcmd!=0x27 && tmpcmd!=0x30  && tmpcmd!=0x32 && tmpcmd!=0x33 && tmpcmd!=0x34 && tmpcmd!=0x3d && tmpcmd!=0xa8 && tmpcmd!=0xee) {
						log("%08X : UnkCMD %08X  %04X  %08X %08X\n", GetTickCount(), CurCOM, PrevVAL, PrevCOM, PrevDAT);
						//systemVerbose |= VERBOSE_LINK; //for testing only
					}

					//rfu_qrecv = 0;
					rfu_counter = 0;
					if ((rfu_qsend2=rfu_qsend=ioMem[0x121]) != 0) { //COMM_SIODATA32_L+1, following data [to send]
						rfu_state = RFU_SEND;
						//rfu_counter = 0;
					}

					if ((rfu_cmd|0x80)!=0x91 && (rfu_cmd|0x80)!=0x93 && ((rfu_cmd|0x80)<0xa4 || (rfu_cmd|0x80)>0xa8)) rfu_lastcmd3 = rfu_cmd;

					if(ioMem[COMM_SIODATA32_L] == 0xee) { //0xee cmd shouldn't override previous cmd
						rfu_lastcmd = rfu_cmd2;
						rfu_cmd2 = ioMem[COMM_SIODATA32_L];
						//rfu_polarity = 0; //when polarity back to normal the game can initiate a new cmd even when 0xee hasn't been finalized, but it looks improper isn't?
					} else {
					rfu_lastcmd = rfu_cmd;
					rfu_cmd = ioMem[COMM_SIODATA32_L];
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
							maskid = ~linkmem->rfu_request[vbaid]; else
							maskid = ~(1<<gbaid);
						//previous important data need to be received successfully before sending another important data
						rfu_lasttime = GetTickCount(); //just to mark the last time a data being sent
						if(!lanlink.speed) {
						while (!AppTerminated && linkmem->numgbas>=2 && linkmem->rfu_q[vbaid]>1 && vbaid!=gbaid && linkmem->rfu_signal[vbaid] && linkmem->rfu_signal[gbaid] && (GetTickCount()-rfu_lasttime)<(DWORD)linktimeout) { //2 players
							if(!rfu_ishost)
							SetEvent(linksync[gbaid]); else //unlock other gba, allow other gba to move (sending their data)  //is max value of vbaid=1 ?
							for(int j=0;j<linkmem->numgbas;j++)
								if(j!=vbaid) SetEvent(linksync[j]);
							WaitForSingleObject(linksync[vbaid], 1); //linktimeout //wait until this gba allowed to move (to prevent both GBAs from using 0x25 at the same time)
							ResetEvent(linksync[vbaid]); //lock this gba, don't allow this gba to move (prevent sending another data too fast w/o giving the other side chances to read it)
							
							//if(PeekMessage(&msg, 0, 0, 0, PM_NOREMOVE)) { //theApp.GetMainWnd()->GetSafeHwnd()
							//	if(msg.message==WM_CLOSE) AppTerminated=true; else theApp.PumpMessage(); //seems to be processing message only if it has message otherwise it halt the program
							//}
							//SleepEx(1,true);
							if (!rfu_ishost && linkmem->rfu_request[vbaid]) {
								c_s.Lock();
								linkmem->rfu_request[vbaid] = 0;
								c_s.Unlock();
								break;
							} //workaround for a bug where rfu_request failed to reset when GBA act as client
						}
						//SetEvent(linksync[vbaid]); //set again to reduce the lag since it will be waited again during finalization cmd
						} else {
						if(linkmem->numgbas>=2 && gbaid!=vbaid && linkmem->rfu_q[vbaid]>1 && linkmem->rfu_signal[vbaid] && linkmem->rfu_signal[gbaid]) { //2 players connected
							if(!rfu_ishost)
							SetEvent(linksync[gbaid]); else //unlock other gba, allow other gba to move (sending their data)  //is max value of vbaid=1 ?
							for(int j=0;j<linkmem->numgbas;j++)
								if(j!=vbaid) SetEvent(linksync[j]);
							WaitForSingleObject(linksync[vbaid], lanlink.speed?1:linktimeout); //linktimeout //wait until this gba allowed to move
							ResetEvent(linksync[vbaid]); //lock this gba, don't allow this gba to move (prevent sending another data too fast w/o giving the other side chances to read it)
						}
						}
						if(linkmem->rfu_q[vbaid]<2 /*|| (!linkmem->rfu_proto[vbaid] && linkmem->rfu_q[vbaid]<=rfu_qsend)*/) { //can overwrite now
							rfu_cansend = true;
							c_s.Lock();
							linkmem->rfu_q[vbaid] = 0; //rfu_qsend;
							linkmem->rfu_qid[vbaid] = 0; //
							c_s.Unlock();
						} else if(!lanlink.speed) rfu_waiting = true; //log("%08X  CMD24: %d %d\n",GetTickCount(),linkmem->rfu_q[vbaid],rfu_qsend2); //don't wait with speedhack
					} else
					if (rfu_cmd==0x25 || rfu_cmd==0x35 /*|| (rfu_cmd==0x24 && linkmem->rfu_q[vbaid]<=rfu_qsend)*/) { //&& linkmem->rfu_q[vbaid]>1
						rfu_lastcmd2 = rfu_cmd;
						rfu_cansend = false;
						//rfu_transfer_end = 1;
						if(rfu_ishost)
							maskid = ~linkmem->rfu_request[vbaid]; else
							maskid = ~(1<<gbaid);
						//previous important data need to be received successfully before sending another important data
						rfu_lasttime = GetTickCount();
						if(!lanlink.speed) {
						while (!AppTerminated && linkmem->numgbas>=2 && linkmem->rfu_q[vbaid]>1 && vbaid!=gbaid && linkmem->rfu_signal[vbaid] && linkmem->rfu_signal[gbaid] && (GetTickCount()-rfu_lasttime)<(DWORD)linktimeout) { //2 players
							if(!rfu_ishost)
							SetEvent(linksync[gbaid]); else //unlock other gba, allow other gba to move (sending their data)  //is max value of vbaid=1 ?
							for(int j=0;j<linkmem->numgbas;j++)
								if(j!=vbaid) SetEvent(linksync[j]);
							WaitForSingleObject(linksync[vbaid], 1); //linktimeout //wait until this gba allowed to move (to prevent both GBAs from using 0x25 at the same time)
							ResetEvent(linksync[vbaid]); //lock this gba, don't allow this gba to move (prevent sending another data too fast w/o giving the other side chances to read it)
							
							//if(PeekMessage(&msg, 0, 0, 0, PM_NOREMOVE)) { //theApp.GetMainWnd()->GetSafeHwnd()
							//	if(msg.message==WM_CLOSE) AppTerminated=true; else theApp.PumpMessage(); //seems to be processing message only if it has message otherwise it halt the program
							//}
							//SleepEx(1,true);
							if (!rfu_ishost && linkmem->rfu_request[vbaid]) {
								c_s.Lock();
								linkmem->rfu_request[vbaid] = 0;
								c_s.Unlock();
								break;
							} //workaround for a bug where rfu_request failed to reset when GBA act as client
						}
						//SetEvent(linksync[vbaid]); //set again to reduce the lag since it will be waited again during finalization cmd
						} else {
						if(linkmem->numgbas>=2 && gbaid!=vbaid && linkmem->rfu_q[vbaid]>1 && linkmem->rfu_signal[vbaid] && linkmem->rfu_signal[gbaid]) { //2 players connected
							if(!rfu_ishost)
							SetEvent(linksync[gbaid]); else //unlock other gba, allow other gba to move (sending their data)  //is max value of vbaid=1 ?
							for(int j=0;j<linkmem->numgbas;j++)
								if(j!=vbaid) SetEvent(linksync[j]);
							WaitForSingleObject(linksync[vbaid], lanlink.speed?1:linktimeout); //linktimeout //wait until this gba allowed to move
							ResetEvent(linksync[vbaid]); //lock this gba, don't allow this gba to move (prevent sending another data too fast w/o giving the other side chances to read it)
						}
						}
						if(linkmem->rfu_q[vbaid]<2) {
							rfu_cansend = true;
							c_s.Lock();
							linkmem->rfu_q[vbaid] = 0; //rfu_qsend;
							linkmem->rfu_qid[vbaid] = 0; //
							c_s.Unlock();
						} else if(!lanlink.speed) rfu_waiting = true; //log("%08X  CMD25: %d %d\n",GetTickCount(),linkmem->rfu_q[vbaid],rfu_qsend2); //don't wait with speedhack
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
					if(rfu_waiting) rfu_buf = READ32LE(&ioMem[COMM_SIODATA32_L]); else
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
						if (linkmem->rfu_request[vbaid]) {
							//gbaid = vbaid^1; //1-vbaid; //linkmem->rfu_request[vbaid] & 1;
							gbaidx = gbaid;
							do {
								gbaidx = (gbaidx+1) % linkmem->numgbas;
								if (gbaidx!=vbaid && linkmem->rfu_reqid[gbaidx]==(vbaid<<3)+0x61f1) rfu_masterdata[rfu_qrecv++] = (gbaidx<<3)+0x61f1;
							} while (gbaidx!=gbaid && linkmem->numgbas>=2); // && linkmem->rfu_reqid[gbaidx]!=(vbaid<<3)+0x61f1
							if (rfu_qrecv>0) {
								bool ok = false;
								for(int i=0; i<rfu_numclients; i++)
								if((rfu_clientlist[i] & 0xffff)==rfu_masterdata[0/*rfu_qrecv-1*/]) {ok = true; break;}
								if(!ok) {
									rfu_curclient = rfu_numclients;
									gbaid = ((rfu_masterdata[0]&0xffff)-0x61f1)>>3; //last joined id
									c_s.Lock();
									linkmem->rfu_signal[gbaid] = 0xffffffff>>((3-(rfu_numclients))<<3);
									linkmem->rfu_clientidx[gbaid] = rfu_numclients;
									c_s.Unlock();
									rfu_clientlist[rfu_numclients] = rfu_masterdata[0/*rfu_qrecv-1*/] | (rfu_numclients++ << 16);
									//rfu_numclients++;
									//log("%d  Switch%02X:%d\n",GetTickCount(),rfu_cmd,gbaid);
									rfu_masterq = 1; //data size
									outbuffer[1] = 0x80|vbaid; //'W'; //destination GBA ID (needed for routing), if dest id = vbaid then it's a broadcast
									outbuffer[0] = (rfu_masterq+2)<<2; //total size including headers //vbaid;
									outbuffer[2] = rfu_cmd;
									outbuffer[3] = rfu_masterq+1;
									memcpy(&outbuffer[4],&linkmem->rfu_signal[gbaid],4);
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
							log("Invalid ID: %04X\n",rfu_id);
						gbaid = (rfu_id-0x61f1)>>3;
						rfu_idx = rfu_id;
						gbaidx = gbaid;
						rfu_lastcmd2 = 0;
						numtransfers = 0;
						c_s.Lock();
						linkmem->rfu_q[vbaid] = 0; //to prevent leftover data from previous session received immediately in the new session
						linkmem->rfu_reqid[vbaid] = rfu_id;
						linkmem->rfu_request[vbaid] = 0; //TODO:might failed to reset rfu_request when being accessed by otherside at the same time, sometimes both acting as client but one of them still have request[vbaid]!=0 //to prevent both GBAs from acting as Host, client can't be a host at the same time
						c_s.Unlock();
						if(vbaid!=gbaid) {
							//if(linkmem->rfu_request[gbaid]) numtransfers++; //if another client already joined
							/*if(!linkmem->rfu_request[gbaid]) rfu_isfirst = true;
							linkmem->rfu_signal[vbaid] = 0x00ff;
							linkmem->rfu_request[gbaid] |= 1<<vbaid;*/ // tells the other GBA(a host) that someone(a client) is joining
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
						//linkmem->rfu_request[vbaid] = 0; //to prevent both GBAs from acting as Host and thinking both of them have Client?
						linkmem->rfu_q[vbaid] = 0; //to prevent leftover data from previous session received immediately in the new session
						c_s.Unlock();
					case 0x1d:	// no visible difference
						c_s.Lock();
						linkmem->rfu_request[vbaid] = 0; //to prevent both GBAs from acting as Host and thinking both of them have Client?
						c_s.Unlock();
						memset(rfu_masterdata, 0, sizeof(linkmem->rfu_bdata[vbaid])); //may not be needed
						rfu_qrecv = 0;
						for(int i=0; i<linkmem->numgbas; i++)
						if(i!=vbaid && linkmem->rfu_bdata[i][0]) {
							memcpy(&rfu_masterdata[rfu_qrecv], linkmem->rfu_bdata[i], sizeof(linkmem->rfu_bdata[i]));
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
						memcpy(&linkmem->rfu_bdata[vbaid][1], &rfu_masterdata[1], sizeof(linkmem->rfu_bdata[vbaid])-4);
						//linkmem->rfu_bdata[vbaid][0] = (vbaid<<3)+0x61f1; //start broadcasting here may cause client to join other client in pokemon coloseum
						//linkmem->rfu_q[vbaid] = 0;
						c_s.Unlock();
						rfu_masterq = (sizeof(linkmem->rfu_bdata[vbaid]) >> 2)-1; //(sizeof(linkmem->rfu_bdata[vbaid])+3) >> 2; //7 dwords
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
						if(linkmem->numgbas>=2 && (linkmem->rfu_request[vbaid]|linkmem->rfu_request[gbaid])) //signal only good when connected
							if(rfu_ishost) { //update, just incase there are leaving clients
								u8 rfureq = linkmem->rfu_request[vbaid];
								u8 oldnum = rfu_numclients;
								rfu_numclients = 0;
								for(int i=0; i<8; i++) {
									if(rfureq & 1) rfu_numclients++;
									rfureq >>= 1;
								}
								if(rfu_numclients>oldnum) rfu_numclients = oldnum; //must not be higher than old value, which means the new client haven't been processed by 0x1a cmd yet
								linkmem->rfu_signal[vbaid] = /*0x00ff*/ 0xffffffff>>((4-rfu_numclients)<<3); 
							} else linkmem->rfu_signal[vbaid] = linkmem->rfu_signal[gbaid]; // /*0x0ff << (linkmem->rfu_clientidx[vbaid]<<3)*/ 0xffffffff>>((3-linkmem->rfu_clientidx[vbaid])<<3);
						else linkmem->rfu_signal[vbaid] = 0;
						c_s.Unlock();
						if (rfu_qrecv==0) {
							rfu_qrecv = 1;
							rfu_masterdata[0] = (u32)linkmem->rfu_signal[vbaid];
						}
						if (rfu_qrecv>0) {
							rfu_state = RFU_RECV; //3;
							int hid = vbaid;
							if(!rfu_ishost) hid = gbaid;
							rfu_masterdata[rfu_qrecv-1] = (u32)linkmem->rfu_signal[hid/*vbaid*//*gbaid*/]; //
						}
						//rfu_transfer_end = 1;
						rfu_cmd ^= 0x80;
						break;

					case 0x33:	// rejoin status check?
						if(linkmem->rfu_signal[vbaid] || numtransfers==0/*|| linkmem->numgbas>=2*/)
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
						if((linkmem->rfu_signal[vbaid] || numtransfers==0/*|| linkmem->numgbas>=2*/) && gbaid!=vbaid)
						rfu_masterdata[0] = ((!rfu_ishost?0x100:0+linkmem->rfu_clientidx[gbaid]) << 16)|((gbaid<<3)+0x61f1); //(linkmem->rfu_clientidx[gbaid] << 16)|((gbaid<<3)+0x61f1); /*0x02001234;*/ else //high word should be 0x0200 ? is 0x0200 means 1st client and 0x4000 means 2nd client?
						rfu_masterdata[0] = 0; //0=error, non-zero=good?
						//numtransfers = 0;
						//linktime = 1;
						rfu_cmd ^= 0x80;
						//rfu_polarity = 0;
						rfu_state = RFU_RECV; //3;
						rfu_qrecv = 1;
						break;

					case 0x13:	// error check?
						if(linkmem->rfu_signal[vbaid] || numtransfers==0 || rfu_initialized /*|| linkmem->numgbas>=2*/)
						rfu_masterdata[0] = ((rfu_ishost?0x100:0+linkmem->rfu_clientidx[vbaid]) << 16)|((vbaid<<3)+0x61f1); /*0x02001234;*/ else //high word should be 0x0200 ? is 0x0200 means 1st client and 0x4000 means 2nd client?
						rfu_masterdata[0] = 0; //0=error, non-zero=good?
						//numtransfers = 0;
						//linktime = 1;
						rfu_cmd ^= 0x80;
						//rfu_polarity = 0;
						rfu_state = RFU_RECV; //3;
						rfu_qrecv = 1;
						break;

					case 0x20:	// client, this has something to do with 0x1f
						rfu_masterdata[0] = (linkmem->rfu_clientidx[vbaid]) << 16; //needed for client
						rfu_masterdata[0] |= (vbaid<<3)+0x61f1; //0x1234; //0x641b; //max id value? Encryption key or Station Mode? (0xFBD9/0xDEAD=Access Point mode?)
						c_s.Lock();
						linkmem->rfu_q[vbaid] = 0; //to prevent leftover data from previous session received immediately in the new session
						linkmem->rfu_request[vbaid] = 0; //TODO:may not works properly, sometimes both acting as client but one of them still have request[vbaid]!=0 //to prevent both GBAs from acting as Host, client can't be a host at the same time
						if(linkmem->rfu_signal[gbaid]<linkmem->rfu_signal[vbaid]) //TODO: why sometimes gbaid and rfu_id is invalid number ?? (rfu_id = 0x0420 causing gbaid to be wrong also)
						linkmem->rfu_signal[gbaid] = linkmem->rfu_signal[vbaid];
						c_s.Unlock();
						rfu_polarity = 0;
						rfu_state = RFU_RECV; //3;
						rfu_qrecv = 1;
						rfu_cmd ^= 0x80;
						break;
					case 0x21:	// client, this too
						rfu_masterdata[0] = (linkmem->rfu_clientidx[vbaid]) << 16; //not needed?
						rfu_masterdata[0] |= (vbaid<<3)+0x61f1; //0x641b; //max id value? Encryption key or Station Mode? (0xFBD9/0xDEAD=Access Point mode?)
						c_s.Lock();
						linkmem->rfu_q[vbaid] = 0; //to prevent leftover data from previous session received immediately in the new session
						linkmem->rfu_request[vbaid] = 0; //TODO:may not works properly, sometimes both acting as client but one of them still have request[vbaid]!=0 //to prevent both GBAs from acting as Host, client can't be a host at the same time
						c_s.Unlock();
						rfu_polarity = 0;
						rfu_state = RFU_RECV; //3;
						rfu_qrecv = 1;
						rfu_cmd ^= 0x80;
						break;

					case 0x19:	// server bind/start listening for client to join, may be used in the middle of host<->client communication w/o causing clients to dc?
						c_s.Lock();
						//linkmem->rfu_request[vbaid] = 0; //to prevent both GBAs from acting as Host and thinking both of them have Client?
						linkmem->rfu_q[vbaid] = 0; //to prevent leftover data from previous session received immediately in the new session
						linkmem->rfu_bdata[vbaid][0] = (vbaid<<3)+0x61f1; //start broadcasting room name
						linkmem->rfu_clientidx[vbaid] = 0;
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
						memcpy(&outbuffer[4],linkmem->rfu_bdata[vbaid],rfu_masterq<<2); //data size (excluding headers)
						LinkSendData(outbuffer, (rfu_masterq+1)<<2, RetryCount, 0); //broadcast
						rfu_cmd ^= 0x80;
						break;

					case 0x1c:	//client, might reset some data?
						//linkmem->rfu_request[vbaid] = 0; //to prevent both GBAs from acting as Host and thinking both of them have Client
						//linkmem->rfu_bdata[vbaid][0] = 0; //stop broadcasting room name
						rfu_ishost = false; //TODO: prevent both GBAs act as client but one of them have rfu_request[vbaid]!=0 on MarioGolfAdv lobby
						//rfu_polarity = 0;
						rfu_numclients = 0;
						rfu_curclient = 0;
						//TODO: is this the cause why rfu_id became 0x0420 ?? and causing gbaid to be wrong also
						//LinkDiscardData(0);
						c_s.Lock();
						//linkmem->rfu_listfront[vbaid] = 0;
						//linkmem->rfu_listback[vbaid] = 0;
						DATALIST.clear();
						linkmem->rfu_clientidx[vbaid] = 0xff00; //highest byte need to be non-zero to make 0x20 cmd to be called repeatedly until join request(0x1f) approved by 0x1a cmd
						c_s.Unlock();
						rfu_cmd ^= 0x80;
						break;

					case 0x1b:	//host, might reset some data? may be used in the middle of host<->client communication w/o causing clients to dc?
						c_s.Lock();
						//linkmem->rfu_request[vbaid] = 0; //to prevent both GBAs from acting as Client and thinking one of them is a Host?
						linkmem->rfu_bdata[vbaid][0] = 0; //0 may cause player unable to join in pokemon union room?
						c_s.Unlock();
						//numtransfers = 0;
						//linktime = 1;
						rfu_masterq = 1; //data size
						outbuffer[1] = 0x80|vbaid; //'W'; //destination GBA ID (needed for routing), if dest id = vbaid then it's a broadcast
						outbuffer[0] = (rfu_masterq+1)<<2; //total size including headers //vbaid;
						outbuffer[2] = rfu_cmd;
						outbuffer[3] = rfu_masterq;
						memcpy(&outbuffer[4],linkmem->rfu_bdata[vbaid],rfu_masterq<<2); //data size (excluding headers)
						LinkSendData(outbuffer, (rfu_masterq+1)<<2, RetryCount, 0); //broadcast
						rfu_cmd ^= 0x80;
						break;

					case 0x30: //reset some data
						if(vbaid!=gbaid) { //(linkmem->numgbas >= 2)
							c_s.Lock();
							//linkmem->rfu_signal[gbaid] = 0;
							linkmem->rfu_request[gbaid] &= ~(1<<vbaid); //linkmem->rfu_request[gbaid] = 0;
							SetEvent(linksync[gbaid]); //allow other gba to move
							c_s.Unlock();
						}
						//WaitForSingleObject(linksync[vbaid], 40/*linktimeout*/);
						while (linkmem->rfu_signal[vbaid]) {
						WaitForSingleObject(linksync[vbaid], 1/*linktimeout*/);
						c_s.Lock();
						linkmem->rfu_signal[vbaid] = 0;
						linkmem->rfu_request[vbaid] = 0; //There is a possibility where rfu_request/signal didn't get zeroed here when it's being read by the other GBA at the same time
						c_s.Unlock();
						//SleepEx(1,true);
						}
						c_s.Lock();
						//linkmem->rfu_listfront[vbaid] = 0;
						//linkmem->rfu_listback[vbaid] = 0;
						DATALIST.clear();
						//linkmem->rfu_clientidx[vbaid] = 0xff00; //highest byte need to be non-zero to make 0x20 cmd to be called repeatedly until join request(0x1f) approved by 0x1a cmd
						//linkmem->rfu_q[vbaid] = 0;
						linkmem->rfu_proto[vbaid] = 0;
						linkmem->rfu_reqid[vbaid] = 0;
						linkmem->rfu_linktime[vbaid] = 0;
						linkmem->rfu_gdata[vbaid] = 0;
						linkmem->rfu_bdata[vbaid][0] = 0;
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
						if(vbaid!=gbaid) { //(linkmem->numgbas >= 2)
							c_s.Lock();
							//linkmem->rfu_signal[gbaid] = 0;
							linkmem->rfu_request[gbaid] &= ~(1<<vbaid); //linkmem->rfu_request[gbaid] = 0;
							SetEvent(linksync[gbaid]); //allow other gba to move
							c_s.Unlock();
						} 
						//WaitForSingleObject(linksync[vbaid], 40/*linktimeout*/);
						while (linkmem->rfu_signal[vbaid]) {
						WaitForSingleObject(linksync[vbaid], 1/*linktimeout*/);
						c_s.Lock();
						linkmem->rfu_signal[vbaid] = 0;
						linkmem->rfu_request[vbaid] = 0; //There is a possibility where rfu_request/signal didn't get zeroed here when it's being read by the other GBA at the same time
						c_s.Unlock();
						//SleepEx(1,true);
						}
						c_s.Lock();
						//linkmem->rfu_listfront[vbaid] = 0;
						//linkmem->rfu_listback[vbaid] = 0;
						DATALIST.clear();
						//linkmem->rfu_clientidx[vbaid] = 0xff00; //highest byte need to be non-zero to make 0x20 cmd to be called repeatedly until join request(0x1f) approved by 0x1a cmd
						//linkmem->rfu_q[vbaid] = 0;
						linkmem->rfu_proto[vbaid] = 0;
						linkmem->rfu_reqid[vbaid] = 0;
						linkmem->rfu_linktime[vbaid] = 0;
						linkmem->rfu_gdata[vbaid] = 0;
						linkmem->rfu_bdata[vbaid][0] = 0;
						linkmem->rfu_clientidx[vbaid] = 0xff00; //highest byte need to be non-zero to make 0x20 cmd to be called repeatedly until join request(0x1f) approved by 0x1a cmd
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
									linkmem->rfu_linktime[gbaid] = tmpDataRec.time;
									c_s.Unlock();
									break;
								}
								
								if(tmpDataRec.len>=rfu_qrecv) {
									//memcpy(linkmem->rfu_data[gbaid], tmpDataRec.data, 4*tmpDataRec.len);
									//linkmem->rfu_qid[gbaid] = tmpDataRec.qid;
									//linkmem->rfu_q[gbaid] = tmpDataRec.len;
									rfu_masterq = rfu_qrecv = tmpDataRec.len;

									//if((linkmem->rfu_qid[gbaid] & (1<<vbaid))) //data is for this GBA
									if(rfu_qrecv!=0) { //data size > 0
										memcpy(rfu_masterdata, tmpDataRec.data/*linkmem->rfu_data[gbaid]*/, min(rfu_masterq<<2,sizeof(rfu_masterdata))); //128 //read data from other GBA
										//linkmem->rfu_qid[gbaid] &= ~(1<<vbaid); //mark as received by this GBA
										//if(linkmem->rfu_request[gbaid]) linkmem->rfu_qid[gbaid] &= linkmem->rfu_request[gbaid]; //remask if it's host, just incase there are client leaving multiplayer
										//if(!linkmem->rfu_qid[gbaid]) linkmem->rfu_q[gbaid] = 0; //mark that it has been fully received
										//if(!linkmem->rfu_q[gbaid] || (rfu_ishost && linkmem->rfu_qid[gbaid]!=linkmem->rfu_request[gbaid])) SetEvent(linksync[gbaid]);
										//linkmem->rfu_qid[gbaid] = 0;
										//linkmem->rfu_q[gbaid] = 0;
										//SetEvent(linksync[gbaid]);
										//log("%08X  CMD26 Recv: %d %d\n",GetTickCount(),rfu_qrecv,linkmem->rfu_q[gbaid]);
									}
								}
							} //else log("%08X  CMD26 Skip: %d %d %d\n",GetTickCount(),rfu_qrecv,linkmem->rfu_q[gbaid],tmpDataRec.len);

							ctr++;
							c_s.Lock();
							//linkmem->rfu_signal[vbaid] &= tmpDataRec.sign; //may cause 3rd players to be not recognized
							//linkmem->rfu_signal[gbaid] = linkmem->rfu_signal[vbaid];
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
							/*if (linkmem->rfu_request[vbaid]) { //is a host
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
							memcpy(linkmem->rfu_data[vbaid],rfu_masterdata,4*rfu_qsend2);
							linkmem->rfu_proto[vbaid] = 0; //UDP-like
							if(rfu_ishost)
								linkmem->rfu_qid[vbaid] = linkmem->rfu_request[vbaid]; else
								linkmem->rfu_qid[vbaid] |= 1<<gbaid;
							linkmem->rfu_q[vbaid] = rfu_qsend2;
							c_s.Unlock();
						} else {
							#ifdef GBA_LOGGING
								if(systemVerbose & VERBOSE_LINK) {
									log("%08X : IgnoredSend[%02X] %d\n", GetTickCount(), rfu_cmd, rfu_qsend2);
								}
							#endif
						}
						//numtransfers++; //not needed, just to keep track
						if((numtransfers++)==0) linktime = 1; //needed to synchronize both performance and for Digimon Racing's client to join successfully //numtransfers used to reset linktime to prevent it from reaching beyond max value of integer? //numtransfers doesn't seems to be used?
						/*c_s.Lock();
						linkmem->rfu_linktime[vbaid] = linktime; //save the ticks before reseted to zero
						c_s.Unlock();*/
						if(rfu_qsend2>0) {
							rfu_masterq = rfu_qsend2; //(sizeof(linkmem->rfu_bdata[vbaid])+3) >> 2; //7 dwords
							if(rfu_ishost)
							outbuffer[1] = 0x80|vbaid; else //'W'; //destination GBA ID (needed for routing), if dest id = vbaid then it's a broadcast
							outbuffer[1] = 0x80|gbaid;
							outbuffer[0] = (rfu_masterq+3)<<2; //total size including headers //vbaid;
							outbuffer[2] = rfu_cmd;
							outbuffer[3] = rfu_masterq+2;
							u32outbuffer[1] = linkmem->rfu_signal[vbaid];
							u32outbuffer[2] = linktime;
							memcpy(&u32outbuffer[3],rfu_masterdata,(rfu_masterq)<<2); //data size (excluding headers)
							LinkSendData(outbuffer, (rfu_masterq+3)<<2, RetryCount, 0); //broadcast
							c_s.Lock();
							if(rfu_qsend2>1)
							linkmem->rfu_state[vbaid] = 1;
							linkmem->rfu_qid[vbaid] = 0;
							linkmem->rfu_q[vbaid] = 0;
							c_s.Unlock();
							//log("%08X  CMD24 Sent: %d %d\n",GetTickCount(),rfu_qsend2,linkmem->rfu_q[vbaid]);
						}
						linktime = 0; //need to zeroed when sending? //0 might cause slowdown in performance
						//rfu_transfer_end = 1;
						rfu_cmd ^= 0x80;
						break;

					case 0x25:	// send [important] data & wait for [important?] reply data
					case 0x35:	// send [important] data & wait for [important?] reply data
						if(rfu_cansend) {
							c_s.Lock();
							memcpy(linkmem->rfu_data[vbaid],rfu_masterdata,4*rfu_qsend2);
							linkmem->rfu_proto[vbaid] = 1; //TCP-like
							if(rfu_ishost)
								linkmem->rfu_qid[vbaid] = linkmem->rfu_request[vbaid]; else
								linkmem->rfu_qid[vbaid] |= 1<<gbaid;
							linkmem->rfu_q[vbaid] = rfu_qsend2;
							c_s.Unlock();
						} else {
							#ifdef GBA_LOGGING
								if(systemVerbose & VERBOSE_LINK) {
									log("%08X : IgnoredSend[%02X] %d\n", GetTickCount(), rfu_cmd, rfu_qsend2);
								}
							#endif
						}
						//numtransfers++; //not needed, just to keep track
						if ((numtransfers++) == 0) linktime = 1; //0; //might be needed to synchronize both performance? //numtransfers used to reset linktime to prevent it from reaching beyond max value of integer? //seems to be needed? otherwise data can't be received properly? //related to 0x24?
						//linktime = 0;
						/*c_s.Lock();
						linkmem->rfu_linktime[vbaid] = linktime; //save the ticks before changed to synchronize performance
						c_s.Unlock();*/
						if(rfu_qsend2>0) {
							rfu_masterq = rfu_qsend2; //(sizeof(linkmem->rfu_bdata[vbaid])+3) >> 2; //7 dwords
							if(rfu_ishost)
							outbuffer[1] = 0x80|vbaid; else //'W'; //destination GBA ID (needed for routing), if dest id = vbaid then it's a broadcast
							outbuffer[1] = 0x80|gbaid;
							outbuffer[0] = (rfu_masterq+3)<<2; //total size including headers //vbaid;
							outbuffer[2] = rfu_cmd;
							outbuffer[3] = rfu_masterq+2;
							u32outbuffer[1] = linkmem->rfu_signal[vbaid];
							u32outbuffer[2] = linktime;
							memcpy(&u32outbuffer[3],rfu_masterdata,rfu_masterq<<2); //data size (excluding headers)
							LinkSendData(outbuffer, (rfu_masterq+3)<<2, RetryCount, 0); //broadcast
							c_s.Lock();
							if(rfu_qsend2>1)
							linkmem->rfu_state[vbaid] = 1;
							linkmem->rfu_qid[vbaid] = 0;
							linkmem->rfu_q[vbaid] = 0;
							c_s.Unlock();
							//log("%08X  CMD25 Sent: %d %d\n",GetTickCount(),rfu_qsend2,linkmem->rfu_q[vbaid]);
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
						linkmem->rfu_linktime[vbaid] = linktime; //save the ticks before changed to synchronize performance
						c_s.Unlock();*/

						rfu_masterq = 2;
						if(rfu_ishost)
						outbuffer[1] = 0x80|vbaid; else //'W'; //destination GBA ID (needed for routing), if dest id = vbaid then it's a broadcast
						outbuffer[1] = 0x80|gbaid;
						outbuffer[0] = (rfu_masterq+1)<<2; //total size including headers //vbaid;
						outbuffer[2] = rfu_cmd;
						outbuffer[3] = rfu_masterq;
						u32outbuffer[1] = linkmem->rfu_signal[vbaid];
						u32outbuffer[2] = linktime;
						LinkSendData(outbuffer, (rfu_masterq+1)<<2, RetryCount, 0);
						//c_s.Lock();
						//linkmem->rfu_state[vbaid] = 1;
						//linkmem->rfu_qid[vbaid] = 0;
						//linkmem->rfu_q[vbaid] = 0;
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
						rfu_transfer_end = linkmem->rfu_linktime[gbaid] - linktime + 1; //+ 256; //waiting ticks = ticks difference between GBAs send/recv? //is max value of vbaid=1 ?
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
					else rfu_buf = READ32LE(&ioMem[COMM_SIODATA32_L]);
					}
				} else { //unknown COMM word //in MarioGolfAdv (when a player/client exiting lobby), There is a possibility COMM = 0x7FFE8001, PrevVAL = 0x5087, PrevCOM = 0, is this part of initialization?
					log("%08X : UnkCOM %08X  %04X  %08X %08X\n", GetTickCount(), READ32LE(&ioMem[COMM_SIODATA32_L]), PrevVAL, PrevCOM, PrevDAT);
					/*rfu_cmd ^= 0x80;
					UPDATE_REG(COMM_SIODATA32_L, 0);
					UPDATE_REG(COMM_SIODATA32_H, 0x8000);*/
					rfu_state = RFU_INIT; //to prevent the next reinit words from getting in finalization processing (here), may cause MarioGolfAdv to show Linking error when this occurs instead of continuing with COMM cmd
					//UPDATE_REG(COMM_SIODATA32_H, READ16LE(&ioMem[COMM_SIODATA32_L])); //replying with reversed words may cause MarioGolfAdv to reinit RFU when COMM = 0x7FFE8001
					//UPDATE_REG(COMM_SIODATA32_L, a);
					rfu_buf = (READ16LE(&ioMem[COMM_SIODATA32_L])<<16)|a;
				}
				break;

			case RFU_SEND: //data following after initialize cmd
				//if(rfu_qsend==0) {rfu_state = RFU_COMM; break;}
				CurDAT = READ32LE(&ioMem[COMM_SIODATA32_L]);
				if(--rfu_qsend == 0) {
					rfu_state = RFU_COMM;
				}

				switch (rfu_cmd) {
				case 0x16:
					//linkmem->rfu_bdata[vbaid][1 + rfu_counter++] = READ32LE(&ioMem[COMM_SIODATA32_L]);
					rfu_masterdata[1 + rfu_counter++] = READ32LE(&ioMem[COMM_SIODATA32_L]);
					break;

				case 0x24:
					//if(linkmem->rfu_proto[vbaid]) break; //important data from 0x25 shouldn't be overwritten by 0x24
				case 0x25:
				case 0x35:
					//rfu_transfer_end = 1;
					//if(rfu_cansend) 
					{
						//c_s.Lock();
						//linkmem->rfu_data[vbaid][rfu_counter++] = READ32LE(&ioMem[COMM_SIODATA32_L]);
						rfu_masterdata[rfu_counter++] = READ32LE(&ioMem[COMM_SIODATA32_L]);
						//c_s.Unlock();
					}
					break;

				default:
					rfu_masterdata[rfu_counter++] = READ32LE(&ioMem[COMM_SIODATA32_L]);
					break;
				}
				//UPDATE_REG(COMM_SIODATA32_L, 0);
				//UPDATE_REG(COMM_SIODATA32_H, 0x8000);
				rfu_buf = 0x80000000;
				break;

			case RFU_RECV: //data following after finalize cmd
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

			#ifdef GBA_LOGGING
				if(systemVerbose & VERBOSE_LINK) {
					if(logstartd)
					if(rfu_state == RFU_COMM)
					st.AppendFormat(_T("   %08X   [%01X, %d, %02X, %02X, %02X, %d, %d, %d, %d] <%08x, %08x>"), rfu_buf/*READ32LE(&ioMem[COMM_SIODATA32_L])*/, rfu_ishost, gbaid, linkmem->rfu_request[vbaid], linkmem->rfu_qid[vbaid], rfu_lastcmd3, numtransfers, rfu_transfer_end, linktime, linkmem->rfu_linktime[vbaid], reg[14].I, armNextPC); else //sometimes getting exception due to "Too small buffer" when st="";
					st.AppendFormat(_T("   %08X                       <%08x, %08x>"), rfu_buf/*READ32LE(&ioMem[COMM_SIODATA32_L])*/, reg[14].I, armNextPC); //
					//st = st2;
					logstartd = false;
				}
			#endif
		}

		if (rfu_polarity)
			value ^= 4;	// sometimes it's the other way around
		/*value &= 0xfffb;
		value |= (value & 1)<<2;*/

		#ifdef GBA_LOGGING
				if(systemVerbose & VERBOSE_LINK) {
					if(st != _T(""))
					log("%s\n", (LPCTSTR)st);
					logstartd = false;
					st = _T("");
					//st2 = _T(""); //st;
				}
		#endif

	default: //other SIO modes
		return value;
	}
}


u16 StartRFU2(u16 value)
{
	static CString st = _T("");
	//static CString st2 = _T(""); //since st.Format can't use it's self (st) as argument we need another CString

	static bool logstartd;
	//MSG msg;
	u32 CurCOM = 0, CurDAT = 0;
	bool rfulogd = (READ16LE(&ioMem[COMM_SIOCNT])!=value);

	switch (GetSIOMode(value, READ16LE(&ioMem[COMM_RCNT]))) {
	case NORMAL8: //occurs after sending 0x996600A8 cmd
		rfu_polarity = 0;
		//log("RFU Wait : %04X  %04X  %d\n", READ16LE(&ioMem[COMM_RCNT]), READ16LE(&ioMem[COMM_SIOCNT]), GetTickCount() );
		return value;
		break;

	case NORMAL32:
		if (transfer) return value; //don't do anything if previous cmd aren't sent yet, may fix Boktai2 Not Detecting wireless adapter

		#ifdef GBA_LOGGING
			if(systemVerbose & VERBOSE_LINK) {
				if(!logstartd)
				if(rfulogd) {
					//log("%08X : %04X  ", GetTickCount(), value);
					st.Format(_T("%08X : %04X[%04X]"), GetTickCount(), value, READ16LE(&ioMem[COMM_SIOCNT]));
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
			//if ((value & 5)==1)
			//value |= 0x02; //wireless always use 2Mhz speed right? this will fix MarioGolfAdv Not Detecting wireless

			//if (transfer) return value; //don't do anything if previous cmd aren't sent yet, may fix Boktai2 Not Detecting wireless adapter

			if ((value & 3) == 1) //internal clock w/ 256KHz speed
				rfu_transfer_end = 2048;
			else //external clock or any clock w/ 2MHz speed
				rfu_transfer_end = 256;

			u16 a = READ16LE(&ioMem[COMM_SIODATA32_H]);

			#ifdef GBA_LOGGING
				if(systemVerbose & VERBOSE_LINK) {
					if(rfulogd)
						st.AppendFormat(_T("    %08X"), READ32LE(&ioMem[COMM_SIODATA32_L])); else
					st.Format(_T("%08X : %04X[%04X]    %08X"), GetTickCount(), value, READ16LE(&ioMem[COMM_SIOCNT]), READ32LE(&ioMem[COMM_SIODATA32_L]));
					//st = st2;
					logstartd = true;
				}
			#endif

			switch (rfu_state) {
			case RFU_INIT:
				if (READ32LE(&ioMem[COMM_SIODATA32_L]) == 0xb0bb8001 /*|| READ32LE(&ioMem[COMM_SIODATA32_L]) == 0x7FFE8001 || READ32LE(&ioMem[COMM_SIODATA32_L]) == 0x80017FFE || READ32LE(&ioMem[COMM_SIODATA32_L]) == 0x8001B0BB*/) { //
					rfu_state = RFU_COMM;	// end of startup
					rfu_initialized = true;
					value &= 0xfffb; //0xff7b; //Bit.2 need to be 0 to indicate a finished initialization to fix MarioGolfAdv from occasionally Not Detecting wireless adapter (prevent it from sending 0x7FFE8001 comm)?
					rfu_polarity = 0; //not needed?
					/*rfu_id = 0;
					rfu_idx = 0;
					gbaid = vbaid;
					gbaidx = gbaid;*/
					//linkmem->rfu_q[vbaid] = 0;
					//RFUClear();
				}
				/*if ((value & 0x500f)==0x5008) { //needed for wireless singlepack? doesn't works yet
					//Downloading game room scanner program from wireless adapter using Multiboot Transfer Protocol
					rfu_buf = (READ16LE(&ioMem[COMM_SIODATA32_L])<<16)|0x6200; //Multiboot Transfer Protocol //bit8..15 = 0x11 or 0x60 or 0x61 or 0x62 or 0x63 or 0x64 or 0x72 or 0x73 ?
				} else*/
				/*if (READ32LE(&ioMem[COMM_SIODATA32_L]) == 0x0) { //workaround to fix Boktai 2 Not Detecting wireless after Game Over?
					value &= 0xff7b;
					UPDATE_REG(COMM_SIODATA32_H, 0x0); //0x0
					UPDATE_REG(COMM_SIODATA32_L, 0x494e); //0x8001
				} else*/ {
					//UPDATE_REG(COMM_SIODATA32_H, READ16LE(&ioMem[COMM_SIODATA32_L]));
					//UPDATE_REG(COMM_SIODATA32_L, a);
					rfu_buf = (READ16LE(&ioMem[COMM_SIODATA32_L])<<16)|a;
				}
				break;

			case RFU_COMM:
				CurCOM = READ32LE(&ioMem[COMM_SIODATA32_L]);
				if (a == 0x9966) //initialize cmd
				{
					u8 tmpcmd = CurCOM;
					if(tmpcmd!=0x10 && tmpcmd!=0x11 && tmpcmd!=0x13 && tmpcmd!=0x14 && tmpcmd!=0x16 && tmpcmd!=0x17 && tmpcmd!=0x19 && tmpcmd!=0x1a && tmpcmd!=0x1b && tmpcmd!=0x1c && tmpcmd!=0x1d && tmpcmd!=0x1e && tmpcmd!=0x1f && tmpcmd!=0x20 && tmpcmd!=0x21 && tmpcmd!=0x24 && tmpcmd!=0x25 && tmpcmd!=0x26 && tmpcmd!=0x27 && tmpcmd!=0x30  && tmpcmd!=0x32 && tmpcmd!=0x33 && tmpcmd!=0x34 && tmpcmd!=0x3d && tmpcmd!=0xa8 && tmpcmd!=0xee) {
						log("%08X : UnkCMD %08X  %04X  %08X %08X\n", GetTickCount(), CurCOM, PrevVAL, PrevCOM, PrevDAT);
						//systemVerbose |= VERBOSE_LINK; //for testing only
					}

					rfu_counter = 0;
					if ((rfu_qsend2=rfu_qsend=ioMem[0x121]) != 0) { //COMM_SIODATA32_L+1, following data [to send]
						rfu_state = RFU_SEND;
						//rfu_counter = 0;
					}

					if ((rfu_cmd|0x80)!=0x91 && (rfu_cmd|0x80)!=0x93 && ((rfu_cmd|0x80)<0xa4 || (rfu_cmd|0x80)>0xa8)) rfu_lastcmd3 = rfu_cmd;

					if(ioMem[COMM_SIODATA32_L] == 0xee) { //0xee cmd shouldn't override previous cmd
						rfu_lastcmd = rfu_cmd2;
						rfu_cmd2 = ioMem[COMM_SIODATA32_L];
						//rfu_polarity = 0; //when polarity back to normal the game can initiate a new cmd even when 0xee hasn't been finalized, but it looks improper isn't?
					} else {
					rfu_lastcmd = rfu_cmd;
					rfu_cmd = ioMem[COMM_SIODATA32_L];
					rfu_cmd2 = 0;
					
					int maskid;
					if (rfu_cmd==0x27 || rfu_cmd==0x37) {
						rfu_lastcmd2 = rfu_cmd;
						rfu_lasttime = GetTickCount();
					} else
					if (rfu_cmd==0x24) { //non-important data shouldn't overwrite important data from 0x25
						rfu_lastcmd2 = rfu_cmd;
						rfu_cansend = false;
						if(rfu_ishost)
							maskid = ~linkmem->rfu_request[vbaid]; else
							maskid = ~(1<<gbaid);
						/*while (!AppTerminated && linkmem->numgbas>=2 && gbaid!=vbaid && (linkmem->rfu_qid[vbaid] & maskid) && linkmem->rfu_q[vbaid] && linkmem->rfu_signal[vbaid]) { //previous data was for a different player
							SleepEx(1,true);
							if(PeekMessage(&msg, 0, 0, 0, PM_NOREMOVE)) { //theApp.GetMainWnd()->GetSafeHwnd()
								if(msg.message==WM_CLOSE) AppTerminated=true; else theApp.PumpMessage(); //seems to be processing message only if it has message otherwise it halt the program
							}
							if(rfu_ishost) { //updates, just incase a client has left the game
								linkmem->rfu_qid[vbaid] &= linkmem->rfu_request[vbaid]; 
								maskid = ~linkmem->rfu_request[vbaid]; 
							}
						}*/
						//previous important data need to be received successfully before sending another important data
						rfu_lasttime = GetTickCount(); //just to mark the last time a data being sent
						if(!speedhack) {
						while (!AppTerminated && linkmem->numgbas>=2 && linkmem->rfu_q[vbaid]>1 && vbaid!=gbaid && linkmem->rfu_signal[vbaid] && linkmem->rfu_signal[gbaid] && (GetTickCount()-rfu_lasttime)<(DWORD)linktimeout) { //2 players
							if(!rfu_ishost)
							SetEvent(linksync[gbaid]); else //unlock other gba, allow other gba to move (sending their data)  //is max value of vbaid=1 ?
							for(int j=0;j<linkmem->numgbas;j++)
								if(j!=vbaid) SetEvent(linksync[j]);
							WaitForSingleObject(linksync[vbaid], 1); //linktimeout //wait until this gba allowed to move (to prevent both GBAs from using 0x25 at the same time)
							ResetEvent(linksync[vbaid]); //lock this gba, don't allow this gba to move (prevent sending another data too fast w/o giving the other side chances to read it)
							
							/*if(PeekMessage(&msg, 0, 0, 0, PM_NOREMOVE)) { //theApp.GetMainWnd()->GetSafeHwnd()
								if(msg.message==WM_CLOSE) AppTerminated=true; else theApp.PumpMessage(); //seems to be processing message only if it has message otherwise it halt the program
							}*/
							//SleepEx(1,true);
							if (!rfu_ishost && linkmem->rfu_request[vbaid]) {linkmem->rfu_request[vbaid]=0;break;} //workaround for a bug where rfu_request failed to reset when GBA act as client
						}
						//SetEvent(linksync[vbaid]); //set again to reduce the lag since it will be waited again during finalization cmd
						} else {
						if(linkmem->numgbas>=2 && gbaid!=vbaid && linkmem->rfu_q[vbaid]>1 && linkmem->rfu_signal[vbaid] && linkmem->rfu_signal[gbaid]) { //2 players connected
							if(!rfu_ishost)
							SetEvent(linksync[gbaid]); else //unlock other gba, allow other gba to move (sending their data)  //is max value of vbaid=1 ?
							for(int j=0;j<linkmem->numgbas;j++)
								if(j!=vbaid) SetEvent(linksync[j]);
							WaitForSingleObject(linksync[vbaid], speedhack?1:linktimeout); //linktimeout //wait until this gba allowed to move
							ResetEvent(linksync[vbaid]); //lock this gba, don't allow this gba to move (prevent sending another data too fast w/o giving the other side chances to read it)
						}
						}
						if(linkmem->rfu_q[vbaid]<2 /*|| (!linkmem->rfu_proto[vbaid] && linkmem->rfu_q[vbaid]<=rfu_qsend)*/) { //can overwrite now
							rfu_cansend = true;
							//linkmem->rfu_proto[vbaid] = 0; //UDP-like
							//if(rfu_ishost)
							//	linkmem->rfu_qid[vbaid] = linkmem->rfu_request[vbaid]; else
							//	linkmem->rfu_qid[vbaid] |= 1<<gbaid;
							linkmem->rfu_q[vbaid] = 0; //rfu_qsend;
							linkmem->rfu_qid[vbaid] = 0; //
						} else if(!speedhack) rfu_waiting = true; //don't wait with speedhack
					} else
					if (rfu_cmd==0x25 || rfu_cmd==0x35 /*|| (rfu_cmd==0x24 && linkmem->rfu_q[vbaid]<=rfu_qsend)*/) { //&& linkmem->rfu_q[vbaid]>1
						rfu_lastcmd2 = rfu_cmd;
						rfu_cansend = false;
						if(rfu_ishost)
							maskid = ~linkmem->rfu_request[vbaid]; else
							maskid = ~(1<<gbaid);
						/*while (!AppTerminated && linkmem->numgbas>=2 && gbaid!=vbaid && (linkmem->rfu_qid[vbaid] & maskid) && linkmem->rfu_q[vbaid] && linkmem->rfu_signal[vbaid]) { //previous data was for a different player
							SleepEx(1,true);
							if(PeekMessage(&msg, 0, 0, 0, PM_NOREMOVE)) { //theApp.GetMainWnd()->GetSafeHwnd()
								if(msg.message==WM_CLOSE) AppTerminated=true; else theApp.PumpMessage(); //seems to be processing message only if it has message otherwise it halt the program
							}
							if(rfu_ishost) { //updates, just incase a client has left the game
								linkmem->rfu_qid[vbaid] &= linkmem->rfu_request[vbaid]; 
								maskid = ~linkmem->rfu_request[vbaid]; 
							}
						}*/
						//previous important data need to be received successfully before sending another important data
						rfu_lasttime = GetTickCount();
						if(!speedhack) {
						while (!AppTerminated && linkmem->numgbas>=2 && linkmem->rfu_q[vbaid]>1 && vbaid!=gbaid && linkmem->rfu_signal[vbaid] && linkmem->rfu_signal[gbaid] && (GetTickCount()-rfu_lasttime)<(DWORD)linktimeout) { //2 players
							if(!rfu_ishost)
							SetEvent(linksync[gbaid]); else //unlock other gba, allow other gba to move (sending their data)  //is max value of vbaid=1 ?
							for(int j=0;j<linkmem->numgbas;j++)
								if(j!=vbaid) SetEvent(linksync[j]);
							WaitForSingleObject(linksync[vbaid], 1); //linktimeout //wait until this gba allowed to move (to prevent both GBAs from using 0x25 at the same time)
							ResetEvent(linksync[vbaid]); //lock this gba, don't allow this gba to move (prevent sending another data too fast w/o giving the other side chances to read it)
							
							/*if(PeekMessage(&msg, 0, 0, 0, PM_NOREMOVE)) { //theApp.GetMainWnd()->GetSafeHwnd()
								if(msg.message==WM_CLOSE) AppTerminated=true; else theApp.PumpMessage(); //seems to be processing message only if it has message otherwise it halt the program
							}*/
							//SleepEx(1,true);
							if (!rfu_ishost && linkmem->rfu_request[vbaid]) {linkmem->rfu_request[vbaid]=0;break;} //workaround for a bug where rfu_request failed to reset when GBA act as client
						}
						//SetEvent(linksync[vbaid]); //set again to reduce the lag since it will be waited again during finalization cmd
						} else {
						if(linkmem->numgbas>=2 && gbaid!=vbaid && linkmem->rfu_q[vbaid]>1 && linkmem->rfu_signal[vbaid] && linkmem->rfu_signal[gbaid]) { //2 players connected
							if(!rfu_ishost)
							SetEvent(linksync[gbaid]); else //unlock other gba, allow other gba to move (sending their data)  //is max value of vbaid=1 ?
							for(int j=0;j<linkmem->numgbas;j++)
								if(j!=vbaid) SetEvent(linksync[j]);
							WaitForSingleObject(linksync[vbaid], speedhack?1:linktimeout); //linktimeout //wait until this gba allowed to move
							ResetEvent(linksync[vbaid]); //lock this gba, don't allow this gba to move (prevent sending another data too fast w/o giving the other side chances to read it)
						}
						}
						if(linkmem->rfu_q[vbaid]<2) {
							rfu_cansend = true;
							/*linkmem->rfu_proto[vbaid] = 1; //TCP-like
							if(rfu_ishost)
								linkmem->rfu_qid[vbaid] = linkmem->rfu_request[vbaid]; else
								linkmem->rfu_qid[vbaid] |= 1<<gbaid;*/
							linkmem->rfu_q[vbaid] = 0; //rfu_qsend;
							linkmem->rfu_qid[vbaid] = 0; //
						} else if(!speedhack) rfu_waiting = true; //don't wait with speedhack
					} else
					if (rfu_cmd==0xa8 || rfu_cmd==0xb6 /*&& rfu_lastcmd2 == 0x25*/) { // && numtransfers == 1
						//wait for [important] data when previously sent is important data, might only need to wait for the 1st 0x25 cmd
						bool ok = false;
						//rfu_lasttime = GetTickCount();
						//while (!AppTerminated && linkmem->numgbas>=2 && vbaid!=gbaid && !(ok) && linkmem->rfu_signal[vbaid] && linkmem->rfu_signal[gbaid] && (GetTickCount()-rfu_lasttime)<1/*(DWORD)linktimeout*/) 
						{ //2 players
							//for(int j=0; j<linkmem->numgbas; j++)
							//if (j!=vbaid)
							//if (linkmem->rfu_q[j] /*&& linkmem->rfu_proto[gbaid]*/) {ok = true; break;}
							/*SleepEx(1,true);
							if(PeekMessage(&msg, 0, 0, 0, PM_NOREMOVE)) { //theApp.GetMainWnd()->GetSafeHwnd()
								if(msg.message==WM_CLOSE) AppTerminated=true; else theApp.PumpMessage(); //seems to be processing message only if it has message otherwise it halt the program
							}*/
						}
						//if(!ok) rfu_transfer_end = 2048;
						//rfu_polarity = 0; //not needed?
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
					if(rfu_waiting) rfu_buf = READ32LE(&ioMem[COMM_SIODATA32_L]); else
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
						if (linkmem->rfu_request[vbaid]) {
							//gbaid = vbaid^1; //1-vbaid; //linkmem->rfu_request[vbaid] & 1;
							gbaidx = gbaid;
							do {
								gbaidx = (gbaidx+1) % linkmem->numgbas;
								if (gbaidx!=vbaid && linkmem->rfu_reqid[gbaidx]==(vbaid<<3)+0x61f1) rfu_masterdata[rfu_qrecv++] = (gbaidx<<3)+0x61f1;
							} while (gbaidx!=gbaid && linkmem->numgbas>=2); // && linkmem->rfu_reqid[gbaidx]!=(vbaid<<3)+0x61f1
							if (rfu_qrecv>0) {
								bool ok = false;
								for(int i=0; i<rfu_numclients; i++)
								if((rfu_clientlist[i] & 0xffff)==rfu_masterdata[0/*rfu_qrecv-1*/]) {ok = true; break;}
								if(!ok) {
									rfu_curclient = rfu_numclients;
									linkmem->rfu_clientidx[(rfu_masterdata[0]-0x61f1)>>3] = rfu_numclients;
									rfu_clientlist[rfu_numclients] = rfu_masterdata[0/*rfu_qrecv-1*/] | (rfu_numclients++ << 16);
									//rfu_numclients++;
									gbaid = (rfu_masterdata[0]-0x61f1)>>3; //last joined id
									linkmem->rfu_signal[gbaid] = 0xffffffff>>((3-(rfu_numclients-1))<<3);
									//log("%d  Switch%02X:%d\n",GetTickCount(),rfu_cmd,gbaid);
								}
									
								if(gbaid==vbaid) {
									gbaid = (rfu_masterdata[0]-0x61f1)>>3; //gbaidx;
								}
								rfu_state = RFU_RECV;
								//rfu_qrecv = 1; //testing
								//for(int i=0; i<rfu_numclients; i++) rfu_masterdata[i] = rfu_clientlist[rfu_numclients-i-1];
							}
						}
						if(rfu_numclients>0) {
							for(int i=0; i<rfu_numclients; i++) rfu_masterdata[i] = rfu_clientlist[i];
							/*rfu_curclient = rfu_numclients-1;
							rfu_id = rfu_clientlist[rfu_curclient];
							gbaid = (rfu_id-0x61f1)>>3;*/
						}
						rfu_id = (gbaid<<3)+0x61f1;
						//rfu_masterdata[0] = rfu_id;
						//linkid = -1; //is this gba id?
						rfu_cmd ^= 0x80;
						break;

					case 0x1f: //join a room as client
						//TODO: to fix infinte send&recv w/o giving much cance to update the screen when both side acting as client on MarioGolfAdv lobby(might be due to leftover data when switching from host to join mode at the same time?)
						rfu_id = rfu_masterdata[0];
						gbaid = (rfu_id-0x61f1)>>3;
						rfu_idx = rfu_id;
						gbaidx = gbaid;
						rfu_lastcmd2 = 0;
						numtransfers = 0;
						linkmem->rfu_q[vbaid] = 0; //to prevent leftover data from previous session received immediately in the new session
						linkmem->rfu_reqid[vbaid] = rfu_id;
						linkmem->rfu_request[vbaid] = 0; //TODO:might failed to reset rfu_request when being accessed by otherside at the same time, sometimes both acting as client but one of them still have request[vbaid]!=0 //to prevent both GBAs from acting as Host, client can't be a host at the same time
						if(vbaid!=gbaid) {
							//if(linkmem->rfu_request[gbaid]) numtransfers++; //if another client already joined
							if(!linkmem->rfu_request[gbaid]) rfu_isfirst = true;
							linkmem->rfu_signal[vbaid] = 0x00ff;
							linkmem->rfu_request[gbaid] |= 1<<vbaid; // tells the other GBA(a host) that someone(a client) is joining
						}
						rfu_cmd ^= 0x80;
						break;

					case 0x1e:	// receive broadcast data
						numtransfers = 0;
						rfu_numclients = 0;
						linkmem->rfu_request[vbaid] = 0; //to prevent both GBAs from acting as Host and thinking both of them have Client?
						linkmem->rfu_q[vbaid] = 0; //to prevent leftover data from previous session received immediately in the new session
					case 0x1d:	// no visible difference
						linkmem->rfu_request[vbaid] = 0; //to prevent both GBAs from acting as Host and thinking both of them have Client?
						memset(rfu_masterdata, 0, sizeof(linkmem->rfu_bdata[vbaid])); //may not be needed
						rfu_qrecv = 0;
						for(int i=0; i<linkmem->numgbas; i++)
						if(i!=vbaid && linkmem->rfu_bdata[i][0]) {
							memcpy(&rfu_masterdata[rfu_qrecv], linkmem->rfu_bdata[i], sizeof(linkmem->rfu_bdata[i]));
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
						//linkmem->rfu_bdata[vbaid][0] = (vbaid<<3)+0x61f1; //start broadcasting here may cause client to join other client in pokemon coloseum
						//linkmem->rfu_q[vbaid] = 0;
						rfu_cmd ^= 0x80;
						break;

					case 0x11:	// get signal strength
						//Switch remote id
							if (linkmem->rfu_request[vbaid]) { //is a host
								/*//gbaid = 1-vbaid; //linkmem->rfu_request[vbaid] & 1;
								gbaidx = gbaid;
								do {
									gbaidx = (gbaidx+1) % linkmem->numgbas;
								} while (gbaidx!=gbaid && linkmem->numgbas>=2 && (linkmem->rfu_reqid[gbaidx]!=(vbaid<<3)+0x61f1 || linkmem->rfu_q[gbaidx]<=0));
								if (gbaidx!=vbaid) {
									gbaid = gbaidx;
									rfu_id = (gbaid<<3)+0x61f1;
								}*/
								/*if(rfu_numclients>0) {
									rfu_curclient = (rfu_curclient+1) % rfu_numclients;
									rfu_id = rfu_clientlist[rfu_curclient];
									gbaid = (rfu_id-0x61f1)>>3;
								}*/
							}
						//check signal
						if(linkmem->numgbas>=2 && (linkmem->rfu_request[vbaid]|linkmem->rfu_request[gbaid])) //signal only good when connected
							if(rfu_ishost) { //update, just incase there are leaving clients
								u8 rfureq = linkmem->rfu_request[vbaid];
								u8 oldnum = rfu_numclients;
								rfu_numclients = 0;
								for(int i=0; i<8; i++) {
									if(rfureq & 1) rfu_numclients++;
									rfureq >>= 1;
								}
								if(rfu_numclients>oldnum) rfu_numclients = oldnum; //must not be higher than old value, which means the new client haven't been processed by 0x1a cmd yet
								linkmem->rfu_signal[vbaid] = /*0x00ff*/ 0xffffffff>>((4-rfu_numclients)<<3); 
							} else linkmem->rfu_signal[vbaid] = linkmem->rfu_signal[gbaid]; // /*0x0ff << (linkmem->rfu_clientidx[vbaid]<<3)*/ 0xffffffff>>((3-linkmem->rfu_clientidx[vbaid])<<3);
						else linkmem->rfu_signal[vbaid] = 0;
						
						if (rfu_ishost) {
							//linkmem->rfu_signal[vbaid] = 0x00ff; //host should have signal to prevent it from canceling the room? (may cause Digimon Racing host not knowing when a client leaving the room)
							/*for (int i=0;i<linkmem->numgbas;i++)
							if (i!=vbaid && linkmem->rfu_reqid[i]==(vbaid<<3)+0x61f1) {
								rfu_masterdata[rfu_qrecv++] = linkmem->rfu_signal[i];
							}*/
							//int j = 0;
							/*int i = gbaid;
							if (linkmem->numgbas>=2)
							do {
								if (i!=vbaid && linkmem->rfu_reqid[i]==(vbaid<<3)+0x61f1) rfu_masterdata[rfu_qrecv++] = linkmem->rfu_signal[i];
								i = (i+1) % linkmem->numgbas;
							} while (i!=gbaid);*/
							/*if(rfu_numclients>0)
							for(int i=0; i<rfu_numclients; i++) {
								u32 cid = (rfu_clientlist[i] & 0x0ffff);
								if(cid>=0x61f1) {
									cid = (cid-0x61f1)>>3;
									rfu_masterdata[rfu_qrecv++] = linkmem->rfu_signal[cid] = 0xffffffff>>((3-linkmem->rfu_clientidx[cid])<<3); //0x0ff << (linkmem->rfu_clientidx[cid]<<3);
								}
							}*/
							//rfu_masterdata[0] = (u32)linkmem->rfu_signal[vbaid];
						}
						if (rfu_qrecv==0) {
							rfu_qrecv = 1;
							rfu_masterdata[0] = (u32)linkmem->rfu_signal[vbaid];
						}
						if (rfu_qrecv>0) {
							rfu_state = RFU_RECV; //3;
							int hid = vbaid;
							if(!rfu_ishost) hid = gbaid;
							rfu_masterdata[rfu_qrecv-1] = (u32)linkmem->rfu_signal[hid/*vbaid*//*gbaid*/]; //
							/*if(rfu_numclients>0) {
								rfu_curclient = (rfu_curclient+1) % rfu_numclients;
								rfu_id = rfu_clientlist[rfu_curclient];
								gbaid = (rfu_id-0x61f1)>>3;
								log("%d  Switch%02X:%d\n",GetTickCount(),rfu_cmd,gbaid);
							}*/
							//rfu_qrecv = 1; //testing
						}
						rfu_cmd ^= 0x80;
						//rfu_polarity = 0;
						//rfu_transfer_end = 2048; //make it longer, giving time for data to come (since 0x26 usually used after 0x11)
						/*//linktime = -2048; //1; //0;
						//numtransfers++; //not needed, just to keep track
						if ((numtransfers++) == 0) linktime = 1; //0; //might be needed to synchronize both performance? //numtransfers used to reset linktime to prevent it from reaching beyond max value of integer? //seems to be needed? otherwise data can't be received properly? //related to 0x24?
						linkmem->rfu_linktime[vbaid] = linktime; //save the ticks before changed to synchronize performance
						rfu_transfer_end = linkmem->rfu_linktime[gbaid] - linktime + 256; //waiting ticks = ticks difference between GBAs send/recv? //is max value of vbaid=1 ?
						if (rfu_transfer_end < 256) //lower/unlimited = faster client but slower host
							rfu_transfer_end = 256; //need to be positive for balanced performance in both GBAs?
						linktime = -rfu_transfer_end; //needed to synchronize performance on both side*/
						break;

					case 0x33:	// rejoin status check?
						if(linkmem->rfu_signal[vbaid] || numtransfers==0/*|| linkmem->numgbas>=2*/)
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
						/*if(rfu_numclients>0) {
							rfu_curclient = 0;
							rfu_id = rfu_clientlist[0]; //return to 1st client index
							gbaid = (rfu_id-0x61f1)>>3;
							log("%d  Switch%02X:%d\n",GetTickCount(),rfu_cmd,gbaid);
						}*/
						if((linkmem->rfu_signal[vbaid] || numtransfers==0/*|| linkmem->numgbas>=2*/) && gbaid!=vbaid)
						rfu_masterdata[0] = ((!rfu_ishost?0x100:0+linkmem->rfu_clientidx[gbaid]) << 16)|((gbaid<<3)+0x61f1); //(linkmem->rfu_clientidx[gbaid] << 16)|((gbaid<<3)+0x61f1); /*0x02001234;*/ else //high word should be 0x0200 ? is 0x0200 means 1st client and 0x4000 means 2nd client?
						rfu_masterdata[0] = 0; //0=error, non-zero=good?
						//numtransfers = 0;
						//linktime = 1;
						rfu_cmd ^= 0x80;
						//rfu_polarity = 0;
						rfu_state = RFU_RECV; //3;
						rfu_qrecv = 1;
						break;

					case 0x13:	// error check?
						if(linkmem->rfu_signal[vbaid] || numtransfers==0 || rfu_initialized /*|| linkmem->numgbas>=2*/)
						rfu_masterdata[0] = ((rfu_ishost?0x100:0+linkmem->rfu_clientidx[vbaid]) << 16)|((vbaid<<3)+0x61f1); /*0x02001234;*/ else //high word should be 0x0200 ? is 0x0200 means 1st client and 0x4000 means 2nd client?
						rfu_masterdata[0] = 0; //0=error, non-zero=good?
						//numtransfers = 0;
						//linktime = 1;
						rfu_cmd ^= 0x80;
						//rfu_polarity = 0;
						rfu_state = RFU_RECV; //3;
						rfu_qrecv = 1;
						break;

					case 0x20:	// client, this has something to do with 0x1f
						rfu_masterdata[0] = (linkmem->rfu_clientidx[vbaid]) << 16; //needed for client
						rfu_masterdata[0] |= (vbaid<<3)+0x61f1; //0x1234; //0x641b; //max id value? Encryption key or Station Mode? (0xFBD9/0xDEAD=Access Point mode?)
						linkmem->rfu_q[vbaid] = 0; //to prevent leftover data from previous session received immediately in the new session
						linkmem->rfu_request[vbaid] = 0; //TODO:may not works properly, sometimes both acting as client but one of them still have request[vbaid]!=0 //to prevent both GBAs from acting as Host, client can't be a host at the same time
						if(linkmem->rfu_signal[gbaid]<linkmem->rfu_signal[vbaid])
						linkmem->rfu_signal[gbaid] = linkmem->rfu_signal[vbaid];
						rfu_polarity = 0;
						rfu_state = RFU_RECV; //3;
						rfu_qrecv = 1;
						rfu_cmd ^= 0x80;
						break;
					case 0x21:	// client, this too
						rfu_masterdata[0] = (linkmem->rfu_clientidx[vbaid]) << 16; //not needed?
						rfu_masterdata[0] |= (vbaid<<3)+0x61f1; //0x641b; //max id value? Encryption key or Station Mode? (0xFBD9/0xDEAD=Access Point mode?)
						linkmem->rfu_q[vbaid] = 0; //to prevent leftover data from previous session received immediately in the new session
						linkmem->rfu_request[vbaid] = 0; //TODO:may not works properly, sometimes both acting as client but one of them still have request[vbaid]!=0 //to prevent both GBAs from acting as Host, client can't be a host at the same time
						rfu_polarity = 0;
						rfu_state = RFU_RECV; //3;
						rfu_qrecv = 1;
						rfu_cmd ^= 0x80;
						break;

					case 0x19:	// server bind/start listening for client to join, may be used in the middle of host<->client communication w/o causing clients to dc?
						//linkmem->rfu_request[vbaid] = 0; //to prevent both GBAs from acting as Host and thinking both of them have Client?
						linkmem->rfu_q[vbaid] = 0; //to prevent leftover data from previous session received immediately in the new session
						linkmem->rfu_bdata[vbaid][0] = (vbaid<<3)+0x61f1; //start broadcasting room name
						linkmem->rfu_clientidx[vbaid] = 0;
						//numtransfers = 0;
						//rfu_numclients = 0;
						//rfu_curclient = 0;
						//rfu_lastcmd2 = 0;
						//rfu_polarity = 0;
						rfu_ishost = true;
						rfu_isfirst = false;
						rfu_cmd ^= 0x80;
						break;

					case 0x1c:	//client, might reset some data?
						//linkmem->rfu_request[vbaid] = 0; //to prevent both GBAs from acting as Host and thinking both of them have Client
						//linkmem->rfu_bdata[vbaid][0] = 0; //stop broadcasting room name
						rfu_ishost = false; //TODO: prevent both GBAs act as client but one of them have rfu_request[vbaid]!=0 on MarioGolfAdv lobby
						//rfu_polarity = 0;
						rfu_numclients = 0;
						rfu_curclient = 0;
						c_s.Lock();
						linkmem->rfu_listfront[vbaid] = 0;
						linkmem->rfu_listback[vbaid] = 0;
						linkmem->rfu_q[vbaid] = 0; //to prevent leftover data from previous session received immediately in the new session
						//DATALIST.clear();
						c_s.Unlock();
					case 0x1b:	//host, might reset some data? may be used in the middle of host<->client communication w/o causing clients to dc?
						//linkmem->rfu_request[vbaid] = 0; //to prevent both GBAs from acting as Client and thinking one of them is a Host?
						linkmem->rfu_bdata[vbaid][0] = 0; //0 may cause player unable to join in pokemon union room?
						//numtransfers = 0;
						//linktime = 1;
						rfu_cmd ^= 0x80;
						break;

					case 0x30: //reset some data
						if(vbaid!=gbaid) { //(linkmem->numgbas >= 2)
							//linkmem->rfu_signal[gbaid] = 0;
							linkmem->rfu_request[gbaid] &= ~(1<<vbaid); //linkmem->rfu_request[gbaid] = 0;
							SetEvent(linksync[gbaid]); //allow other gba to move
						}
						//WaitForSingleObject(linksync[vbaid], 40/*linktimeout*/);
						while (linkmem->rfu_signal[vbaid]) {
						WaitForSingleObject(linksync[vbaid], 1/*linktimeout*/);
						linkmem->rfu_signal[vbaid] = 0;
						linkmem->rfu_request[vbaid] = 0; //There is a possibility where rfu_request/signal didn't get zeroed here when it's being read by the other GBA at the same time
						//SleepEx(1,true);
						}
						c_s.Lock();
						linkmem->rfu_listfront[vbaid] = 0;
						linkmem->rfu_listback[vbaid] = 0;
						linkmem->rfu_q[vbaid] = 0; //to prevent leftover data from previous session received immediately in the new session
						//DATALIST.clear();
						linkmem->rfu_proto[vbaid] = 0;
						linkmem->rfu_reqid[vbaid] = 0;
						linkmem->rfu_linktime[vbaid] = 0;
						linkmem->rfu_gdata[vbaid] = 0;
						linkmem->rfu_bdata[vbaid][0] = 0;
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
						if(vbaid!=gbaid) { //(linkmem->numgbas >= 2)
							//linkmem->rfu_signal[gbaid] = 0;
							linkmem->rfu_request[gbaid] &= ~(1<<vbaid); //linkmem->rfu_request[gbaid] = 0;
							SetEvent(linksync[gbaid]); //allow other gba to move
						} 
						//WaitForSingleObject(linksync[vbaid], 40/*linktimeout*/);
						while (linkmem->rfu_signal[vbaid]) {
						WaitForSingleObject(linksync[vbaid], 1/*linktimeout*/);
						linkmem->rfu_signal[vbaid] = 0;
						linkmem->rfu_request[vbaid] = 0; //There is a possibility where rfu_request/signal didn't get zeroed here when it's being read by the other GBA at the same time
						//SleepEx(1,true);
						}
						c_s.Lock();
						linkmem->rfu_listfront[vbaid] = 0;
						linkmem->rfu_listback[vbaid] = 0;
						linkmem->rfu_q[vbaid] = 0; //to prevent leftover data from previous session received immediately in the new session
						//DATALIST.clear();
						linkmem->rfu_proto[vbaid] = 0;
						linkmem->rfu_reqid[vbaid] = 0;
						linkmem->rfu_linktime[vbaid] = 0;
						linkmem->rfu_gdata[vbaid] = 0;
						linkmem->rfu_bdata[vbaid][0] = 0;
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
						/*//if(vbaid==gbaid) {
							if(linkmem->numgbas>=2)
							if((linkmem->rfu_q[gbaid]<=0) || !(linkmem->rfu_qid[gbaid] & (1<<vbaid))) //current remote id doesn't have data
							//do
							{
							if(rfu_numclients>0) { //is a host
								u8 cc = rfu_curclient;
								do {
									rfu_curclient = (rfu_curclient+1) % rfu_numclients;
									rfu_idx = rfu_clientlist[rfu_curclient];
									gbaidx = (rfu_idx-0x61f1)>>3;
								} while (!AppTerminated && cc!=rfu_curclient && rfu_numclients>=1 && (!(linkmem->rfu_qid[gbaidx] & (1<<vbaid)) || linkmem->rfu_q[gbaidx]<=0));
								if (cc!=rfu_curclient) { //gbaidx!=vbaid && gbaidx!=gbaid
									gbaid = gbaidx;
									rfu_id = rfu_idx;
									//log("%d  Switch%02X:%d\n",GetTickCount(),rfu_cmd,gbaid);
									//if(linkmem->rfu_q[gbaid]>0 || rfu_lastcmd2==0) 
									//break;
								}
							}
							//SleepEx(1,true);
							} //while (!AppTerminated && gbaid!=vbaid && linkmem->numgbas>=2 && linkmem->rfu_signal[gbaid] && linkmem->rfu_q[gbaid]<=0 && linkmem->rfu_q[vbaid]>0 && (GetTickCount()-rfu_lasttime)<1); //(DWORD)linktimeout
						}*/

						//Wait for data
						
						//Read data when available
						/*if((linkmem->rfu_qid[gbaid] & (1<<vbaid))) //data is for this GBA
						if((rfu_qrecv=rfu_masterq=linkmem->rfu_q[gbaid])!=0) { //data size > 0
							memcpy(rfu_masterdata, linkmem->rfu_data[gbaid], min(rfu_masterq<<2,sizeof(rfu_masterdata))); //128 //read data from other GBA
							linkmem->rfu_qid[gbaid] &= ~(1<<vbaid); //mark as received by this GBA
							if(linkmem->rfu_request[gbaid]) linkmem->rfu_qid[gbaid] &= linkmem->rfu_request[gbaid]; //remask if it's host, just incase there are client leaving multiplayer
							if(!linkmem->rfu_qid[gbaid]) linkmem->rfu_q[gbaid] = 0; //mark that it has been fully received
							if(!linkmem->rfu_q[gbaid]) SetEvent(linksync[gbaid]); // || (rfu_ishost && linkmem->rfu_qid[gbaid]!=linkmem->rfu_request[gbaid])
							//ResetEvent(linksync[vbaid]); //linksync[vbaid] //lock this gba, don't allow this gba to move (prevent both GBA using 0x25 at the same time) //slower but improve stability by preventing both GBAs from using 0x25 at the same time
							//SetEvent(linksync[1-vbaid]); //unlock other gba, allow other gba to move (sending their data) //faster but may affect stability and cause both GBAs using 0x25 at the same time, too fast communication could also cause the game from updating the screen
						}*/
						bool ok;
						int ctr;
						ctr = 0;
						//WaitForSingleObject(linksync[vbaid], linktimeout); //wait until unlocked
						//ResetEvent(linksync[vbaid]); //lock it so noone can access it
						if(linkmem->rfu_listfront[vbaid]!=linkmem->rfu_listback[vbaid]) //data existed
						do {
							u8 tmpq = linkmem->rfu_datalist[vbaid][linkmem->rfu_listfront[vbaid]].len; //(u8)linkmem->rfu_qlist[vbaid][linkmem->rfu_listfront[vbaid]];
							ok = false;
							if(tmpq!=rfu_qrecv) ok = true; else
							for(int i=0; i<tmpq; i++)
								if(linkmem->rfu_datalist[vbaid][linkmem->rfu_listfront[vbaid]].data[i]!=rfu_masterdata[i]) {ok = true; break;}

							if(tmpq==0 && ctr==0) ok = true; //0-size data

							if(ok) //next data is not a duplicate of currently unprocessed data
							if(rfu_qrecv<2 || tmpq>1) 
							{
								if(rfu_qrecv>1) { //stop here if next data is different than currently unprocessed non-ping data
									linkmem->rfu_linktime[gbaid] = linkmem->rfu_datalist[vbaid][linkmem->rfu_listfront[vbaid]].time;
									break; 
								}

								if(tmpq>=rfu_qrecv) {
									rfu_masterq = rfu_qrecv = tmpq;
									gbaid = linkmem->rfu_datalist[vbaid][linkmem->rfu_listfront[vbaid]].gbaid;
									rfu_id = (gbaid<<3)+0x61f1;
									if(rfu_ishost)
									rfu_curclient = (u8)linkmem->rfu_clientidx[gbaid];
									if(rfu_qrecv!=0) { //data size > 0
										memcpy(rfu_masterdata, linkmem->rfu_datalist[vbaid][linkmem->rfu_listfront[vbaid]].data, min(rfu_masterq<<2,sizeof(rfu_masterdata)));
									}
								}
							} //else log("%08X  CMD26 Skip: %d %d %d\n",GetTickCount(),rfu_qrecv,linkmem->rfu_q[gbaid],tmpq);
							
							linkmem->rfu_listfront[vbaid]++; ctr++;

							ok = (linkmem->rfu_listfront[vbaid]!=linkmem->rfu_listback[vbaid] && linkmem->rfu_datalist[vbaid][linkmem->rfu_listfront[vbaid]].gbaid==gbaid);
						} while (ok);
						//SetEvent(linksync[vbaid]); //unlock it so anyone can access it
						
						if (rfu_qrecv>0) { //data was available
							rfu_state = RFU_RECV;
							rfu_counter = 0;
							rfu_lastcmd2 = 0;
							
							//Switch remote id to next remote id
							/*if (linkmem->rfu_request[vbaid]) { //is a host
								if(rfu_numclients>0) {
									rfu_curclient = (rfu_curclient+1) % rfu_numclients;
									rfu_id = rfu_clientlist[rfu_curclient];
									gbaid = (rfu_id-0x61f1)>>3;
									//log("%d  SwitchNext%02X:%d\n",GetTickCount(),rfu_cmd,gbaid);
								}
							}*/
						}
						/*if(vbaid!=gbaid && linkmem->rfu_request[vbaid] && linkmem->rfu_request[gbaid])
							MessageBox(0,_T("Both GBAs are Host!"),_T("Warning"),0);*/
						rfu_cmd ^= 0x80;
						break;

					case 0x24:	// send [non-important] data (used by server often)
						//numtransfers++; //not needed, just to keep track
						if((numtransfers++)==0) linktime = 1; //needed to synchronize both performance and for Digimon Racing's client to join successfully //numtransfers used to reset linktime to prevent it from reaching beyond max value of integer? //numtransfers doesn't seems to be used?
						//linkmem->rfu_linktime[vbaid] = linktime; //save the ticks before reseted to zero

						if(rfu_cansend && rfu_qsend2>=0) {
							/*memcpy(linkmem->rfu_data[vbaid],rfu_masterdata,4*rfu_qsend2);
							linkmem->rfu_proto[vbaid] = 0; //UDP-like
							if(rfu_ishost)
								linkmem->rfu_qid[vbaid] = linkmem->rfu_request[vbaid]; else
								linkmem->rfu_qid[vbaid] |= 1<<gbaid;
							linkmem->rfu_q[vbaid] = rfu_qsend2;*/
							if(rfu_ishost) {
								for(int j=0;j<linkmem->numgbas;j++) 
								if(j!=vbaid)
								{
									WaitForSingleObject(linksync[j], linktimeout); //wait until unlocked
									ResetEvent(linksync[j]); //lock it so noone can access it
									memcpy(linkmem->rfu_datalist[j][linkmem->rfu_listback[j]].data,rfu_masterdata,4*rfu_qsend2);
									linkmem->rfu_datalist[j][linkmem->rfu_listback[j]].gbaid = vbaid;
									linkmem->rfu_datalist[j][linkmem->rfu_listback[j]].len = rfu_qsend2;
									linkmem->rfu_datalist[j][linkmem->rfu_listback[j]].time = linktime;
									linkmem->rfu_listback[j]++;
									SetEvent(linksync[j]); //unlock it so anyone can access it
								}
							} else 
							if(vbaid!=gbaid) {
								WaitForSingleObject(linksync[gbaid], linktimeout); //wait until unlocked
								ResetEvent(linksync[gbaid]); //lock it so noone can access it
								memcpy(linkmem->rfu_datalist[gbaid][linkmem->rfu_listback[gbaid]].data,rfu_masterdata,4*rfu_qsend2);
								linkmem->rfu_datalist[gbaid][linkmem->rfu_listback[gbaid]].gbaid = vbaid;
								linkmem->rfu_datalist[gbaid][linkmem->rfu_listback[gbaid]].len = rfu_qsend2;
								linkmem->rfu_datalist[gbaid][linkmem->rfu_listback[gbaid]].time = linktime;
								linkmem->rfu_listback[gbaid]++;
								SetEvent(linksync[gbaid]); //unlock it so anyone can access it
							}
						} else {
							#ifdef GBA_LOGGING
								if(systemVerbose & VERBOSE_LINK) {
									log("%08X : IgnoredSend[%02X] %d\n", GetTickCount(), rfu_cmd, rfu_qsend2);
								}
							#endif
						}
		
						linktime = 0; //need to zeroed when sending? //0 might cause slowdown in performance
						rfu_cmd ^= 0x80;
						//linkid = -1; //not needed?
						break;

					case 0x25:	// send [important] data & wait for [important?] reply data
					case 0x35:	// send [important] data & wait for [important?] reply data
						//numtransfers++; //not needed, just to keep track
						if ((numtransfers++) == 0) linktime = 1; //0; //might be needed to synchronize both performance? //numtransfers used to reset linktime to prevent it from reaching beyond max value of integer? //seems to be needed? otherwise data can't be received properly? //related to 0x24?
						//linktime = 0;
						//linkmem->rfu_linktime[vbaid] = linktime; //save the ticks before changed to synchronize performance

						if(rfu_cansend && rfu_qsend2>=0) {
							/*memcpy(linkmem->rfu_data[vbaid],rfu_masterdata,4*rfu_qsend2);
							linkmem->rfu_proto[vbaid] = 1; //TCP-like
							if(rfu_ishost)
								linkmem->rfu_qid[vbaid] = linkmem->rfu_request[vbaid]; else
								linkmem->rfu_qid[vbaid] |= 1<<gbaid;
							linkmem->rfu_q[vbaid] = rfu_qsend2;*/
							if(rfu_ishost) {
								for(int j=0;j<linkmem->numgbas;j++) 
								if(j!=vbaid)
								{
									WaitForSingleObject(linksync[j], linktimeout); //wait until unlocked
									ResetEvent(linksync[j]); //lock it so noone can access it
									memcpy(linkmem->rfu_datalist[j][linkmem->rfu_listback[j]].data,rfu_masterdata,4*rfu_qsend2);
									linkmem->rfu_datalist[j][linkmem->rfu_listback[j]].gbaid = vbaid;
									linkmem->rfu_datalist[j][linkmem->rfu_listback[j]].len = rfu_qsend2;
									linkmem->rfu_datalist[j][linkmem->rfu_listback[j]].time = linktime;
									linkmem->rfu_listback[j]++;
									SetEvent(linksync[j]); //unlock it so anyone can access it
								}
							} else 
							if(vbaid!=gbaid) {
								WaitForSingleObject(linksync[gbaid], linktimeout); //wait until unlocked
								ResetEvent(linksync[gbaid]); //lock it so noone can access it
								memcpy(linkmem->rfu_datalist[gbaid][linkmem->rfu_listback[gbaid]].data,rfu_masterdata,4*rfu_qsend2);
								linkmem->rfu_datalist[gbaid][linkmem->rfu_listback[gbaid]].gbaid = vbaid;
								linkmem->rfu_datalist[gbaid][linkmem->rfu_listback[gbaid]].len = rfu_qsend2;
								linkmem->rfu_datalist[gbaid][linkmem->rfu_listback[gbaid]].time = linktime;
								linkmem->rfu_listback[gbaid]++;
								SetEvent(linksync[gbaid]); //unlock it so anyone can access it
							}
						} else {
							#ifdef GBA_LOGGING
								if(systemVerbose & VERBOSE_LINK) {
									log("%08X : IgnoredSend[%02X] %d\n", GetTickCount(), rfu_cmd, rfu_qsend2);
								}
							#endif
						}
						//numtransfers++; //not needed, just to keep track
						//if((numtransfers++)==0) linktime = 1; //may not be needed here?
						//linkmem->rfu_linktime[vbaid] = linktime; //may not be needed here? save the ticks before reseted to zero
						//linktime = 0; //may not be needed here? //need to zeroed when sending? //0 might cause slowdown in performance
						//TODO: there is still a chance for 0x25 to be used at the same time on both GBA (both GBAs acting as client but keep sending & receiving using 0x25 & 0x26 for infinity w/o updating the screen much)
						//Waiting here for previous data to be received might be too late! as new data already sent before finalization cmd
					case 0x27:	// wait for data ?
					case 0x37:	// wait for data ?
						//numtransfers++; //not needed, just to keep track
						if ((numtransfers++) == 0) linktime = 1; //0; //might be needed to synchronize both performance? //numtransfers used to reset linktime to prevent it from reaching beyond max value of integer? //seems to be needed? otherwise data can't be received properly? //related to 0x24?
						//linktime = 0;
						//linkmem->rfu_linktime[vbaid] = linktime; //save the ticks before changed to synchronize performance

							if(rfu_ishost) {
								for(int j=0;j<linkmem->numgbas;j++) 
								if(j!=vbaid)
								{
									WaitForSingleObject(linksync[j], linktimeout); //wait until unlocked
									ResetEvent(linksync[j]); //lock it so noone can access it
									//memcpy(linkmem->rfu_datalist[j][linkmem->rfu_listback[j]].data,rfu_masterdata,4*rfu_qsend2);
									linkmem->rfu_datalist[j][linkmem->rfu_listback[j]].gbaid = vbaid;
									linkmem->rfu_datalist[j][linkmem->rfu_listback[j]].len = 0; //rfu_qsend2;
									linkmem->rfu_datalist[j][linkmem->rfu_listback[j]].time = linktime;
									linkmem->rfu_listback[j]++;
									SetEvent(linksync[j]); //unlock it so anyone can access it
								}
							} else 
							if(vbaid!=gbaid) {
								WaitForSingleObject(linksync[gbaid], linktimeout); //wait until unlocked
								ResetEvent(linksync[gbaid]); //lock it so noone can access it
								//memcpy(linkmem->rfu_datalist[gbaid][linkmem->rfu_listback[gbaid]].data,rfu_masterdata,4*rfu_qsend2);
								linkmem->rfu_datalist[gbaid][linkmem->rfu_listback[gbaid]].gbaid = vbaid;
								linkmem->rfu_datalist[gbaid][linkmem->rfu_listback[gbaid]].len = 0; //rfu_qsend2;
								linkmem->rfu_datalist[gbaid][linkmem->rfu_listback[gbaid]].time = linktime;
								linkmem->rfu_listback[gbaid]++;
								SetEvent(linksync[gbaid]); //unlock it so anyone can access it
							}

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
						if(linkmem->rfu_listfront[vbaid]!=linkmem->rfu_listback[vbaid]) {
							rfu_polarity = 1; //reverse polarity to make the game send 0x80000000 command word (to be replied with 0x99660028 later by the adapter)
							if(rfu_cmd==0xa5 || rfu_cmd==0xa7) rfu_cmd = 0x28; else rfu_cmd = 0x36; //there might be 0x29 also //don't return 0x28 yet until there is incoming data (or until 500ms-6sec timeout? may reset RFU after timeout)
						} else 
						rfu_waiting = true;

						/*//numtransfers++; //not needed, just to keep track
						if ((numtransfers++) == 0) linktime = 1; //0; //might be needed to synchronize both performance? //numtransfers used to reset linktime to prevent it from reaching beyond max value of integer? //seems to be needed? otherwise data can't be received properly? //related to 0x24?
						//linktime = 0;
						//if (rfu_cmd==0xa5)
						linkmem->rfu_linktime[vbaid] = linktime; //save the ticks before changed to synchronize performance
						*/

						//prevent GBAs from sending data at the same time (which may cause waiting at the same time in the case of 0x25), also gives time for the other side to read the data
						//if (linkmem->numgbas>=2 && linkmem->rfu_signal[vbaid] && linkmem->rfu_signal[gbaid]) {
							/*SetEvent(linksync[gbaid]); //allow other gba to move (sending their data)
							WaitForSingleObject(linksync[vbaid], 1); //linktimeout //wait until this gba allowed to move
							//if(rfu_cmd==0xa5) 
							ResetEvent(linksync[vbaid]);*/ //don't allow this gba to move (prevent sending another data too fast w/o giving the other side chances to read it)
						//}
						
						rfu_transfer_end = linkmem->rfu_linktime[gbaid] - linktime + 1; //256; //waiting ticks = ticks difference between GBAs send/recv? //is max value of vbaid=1 ?
						
						if (rfu_transfer_end > 2560) //may need to cap the max ticks to prevent some games (ie. pokemon) from getting in-game timeout due to executing too many opcodes (too fast)
							rfu_transfer_end = 2560; //10240;

						if (rfu_transfer_end < 256) //lower/unlimited = faster client but slower host
							rfu_transfer_end = 256; //need to be positive for balanced performance in both GBAs?

						linktime = -rfu_transfer_end; //needed to synchronize performance on both side
						break;
					}
					//UPDATE_REG(COMM_SIODATA32_H, 0x9966);
					//UPDATE_REG(COMM_SIODATA32_L, (rfu_qrecv<<8) | rfu_cmd);
					if(!rfu_waiting)
					rfu_buf = 0x99660000|(rfu_qrecv<<8) | rfu_cmd; 
					else rfu_buf = READ32LE(&ioMem[COMM_SIODATA32_L]);
					}
				} else { //unknown COMM word //in MarioGolfAdv (when a player/client exiting lobby), There is a possibility COMM = 0x7FFE8001, PrevVAL = 0x5087, PrevCOM = 0, is this part of initialization?
					log("%08X : UnkCOM %08X  %04X  %08X %08X\n", GetTickCount(), READ32LE(&ioMem[COMM_SIODATA32_L]), PrevVAL, PrevCOM, PrevDAT);
					/*rfu_cmd ^= 0x80;
					UPDATE_REG(COMM_SIODATA32_L, 0);
					UPDATE_REG(COMM_SIODATA32_H, 0x8000);*/
					rfu_state = RFU_INIT; //to prevent the next reinit words from getting in finalization processing (here), may cause MarioGolfAdv to show Linking error when this occurs instead of continuing with COMM cmd
					//UPDATE_REG(COMM_SIODATA32_H, READ16LE(&ioMem[COMM_SIODATA32_L])); //replying with reversed words may cause MarioGolfAdv to reinit RFU when COMM = 0x7FFE8001
					//UPDATE_REG(COMM_SIODATA32_L, a);
					rfu_buf = (READ16LE(&ioMem[COMM_SIODATA32_L])<<16)|a;
				}
				break;

			case RFU_SEND: //data following after initialize cmd
				//if(rfu_qsend==0) {rfu_state = RFU_COMM; break;}
				CurDAT = READ32LE(&ioMem[COMM_SIODATA32_L]);
				if(--rfu_qsend == 0) {
					rfu_state = RFU_COMM;
				}

				switch (rfu_cmd) {
				case 0x16:
					linkmem->rfu_bdata[vbaid][1 + rfu_counter++] = READ32LE(&ioMem[COMM_SIODATA32_L]);
					break;

				case 0x17:
					//linkid = 1;
					rfu_masterdata[rfu_counter++] = READ32LE(&ioMem[COMM_SIODATA32_L]);
					break;

				case 0x1f:
					rfu_masterdata[rfu_counter++] = READ32LE(&ioMem[COMM_SIODATA32_L]);
					break;

				case 0x24:
					//if(linkmem->rfu_proto[vbaid]) break; //important data from 0x25 shouldn't be overwritten by 0x24
				case 0x25:
				case 0x35:
					//if(rfu_cansend)
					//linkmem->rfu_data[vbaid][rfu_counter++] = READ32LE(&ioMem[COMM_SIODATA32_L]);
					rfu_masterdata[rfu_counter++] = READ32LE(&ioMem[COMM_SIODATA32_L]);
					break;

				default:
					rfu_masterdata[rfu_counter++] = READ32LE(&ioMem[COMM_SIODATA32_L]);
					break;
				}
				//UPDATE_REG(COMM_SIODATA32_L, 0);
				//UPDATE_REG(COMM_SIODATA32_H, 0x8000);
				rfu_buf = 0x80000000;
				break;

			case RFU_RECV: //data following after finalize cmd
				//if(rfu_qrecv==0) {rfu_state = RFU_COMM; break;}
				if (--rfu_qrecv == 0)
					rfu_state = RFU_COMM;

				switch (rfu_cmd) {
				case 0x9d:
				case 0x9e:
					//UPDATE_REG(COMM_SIODATA32_L, rfu_masterdata[rfu_counter]&0xffff);
					//UPDATE_REG(COMM_SIODATA32_H, rfu_masterdata[rfu_counter++]>>16);
					rfu_buf = rfu_masterdata[rfu_counter++];
					break;

				case 0xb6:
				case 0xa6:
					//UPDATE_REG(COMM_SIODATA32_L, rfu_masterdata[rfu_counter]&0xffff);
					//UPDATE_REG(COMM_SIODATA32_H, rfu_masterdata[rfu_counter++]>>16);
					rfu_buf = rfu_masterdata[rfu_counter++];
					break;

				case 0x91: //signal strength
					//UPDATE_REG(COMM_SIODATA32_L, rfu_masterdata[rfu_counter]&0xffff);
					//UPDATE_REG(COMM_SIODATA32_H, rfu_masterdata[rfu_counter++]>>16);
					rfu_buf = rfu_masterdata[rfu_counter++];
					break;

				case 0xb3: //rejoin error code?
					/*UPDATE_REG(COMM_SIODATA32_L, 2); //0 = success, 1 = failed, 0x2++ = invalid
					UPDATE_REG(COMM_SIODATA32_H, 0x0000); //high word 0 = a success indication?
					break;*/
				case 0x94:	//last error code? //it seems like the game doesn't care about this value
				case 0x93:	//last error code? //it seems like the game doesn't care about this value
					/*if(linkmem->rfu_signal[vbaid] || linkmem->numgbas>=2) {
						UPDATE_REG(COMM_SIODATA32_L, 0x1234);	// put anything in here
						UPDATE_REG(COMM_SIODATA32_H, 0x0200);	// also here, but it should be 0200
					} else {
						UPDATE_REG(COMM_SIODATA32_L, 0);	// put anything in here
						UPDATE_REG(COMM_SIODATA32_H, 0x0000);
					}*/
					//UPDATE_REG(COMM_SIODATA32_L, rfu_masterdata[rfu_counter]&0xffff);
					//UPDATE_REG(COMM_SIODATA32_H, rfu_masterdata[rfu_counter++]>>16);
					rfu_buf = rfu_masterdata[rfu_counter++];
					break;

				case 0xa0:
					//UPDATE_REG(COMM_SIODATA32_L, rfu_masterdata[rfu_counter]&0xffff); //max id value? Encryption key or Station Mode? (0xFBD9/0xDEAD=Access Point mode?)
					//UPDATE_REG(COMM_SIODATA32_H, rfu_masterdata[rfu_counter++]>>16); //high word 0 = a success indication?
					rfu_buf = rfu_masterdata[rfu_counter++];
					break;
				case 0xa1:
					//UPDATE_REG(COMM_SIODATA32_L, rfu_masterdata[rfu_counter]&0xffff); //max id value? the same with 0xa0 cmd?
					//UPDATE_REG(COMM_SIODATA32_H, rfu_masterdata[rfu_counter++]>>16); //high word 0 = a success indication?
					rfu_buf = rfu_masterdata[rfu_counter++];
					break;

				case 0x9a:
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

			#ifdef GBA_LOGGING
				if(systemVerbose & VERBOSE_LINK) {
					if(logstartd)
					if(rfu_state == RFU_COMM)
					st.AppendFormat(_T("   %08X   [%01X, %d, %02X, %02X, %02X, %d, %d, %d, %d] <%08x, %08x>"), rfu_buf/*READ32LE(&ioMem[COMM_SIODATA32_L])*/, rfu_ishost, gbaid, linkmem->rfu_request[vbaid], linkmem->rfu_qid[vbaid], rfu_lastcmd3, numtransfers, rfu_transfer_end, linktime, linkmem->rfu_linktime[vbaid], reg[14].I, armNextPC); else //sometimes getting exception due to "Too small buffer" when st="";
					st.AppendFormat(_T("   %08X                       <%08x, %08x>"), rfu_buf/*READ32LE(&ioMem[COMM_SIODATA32_L])*/, reg[14].I, armNextPC); //
					//st = st2;
					logstartd = false;
				}
			#endif
		}

		//Moved from the top to fix Mario Golf Adv from Occasionally Not Detecting wireless adapter
		/*if (value & 8) //Transfer Enable Flag Send (bit.3, 1=Disable Transfer/Not Ready)
			value &= 0xfffb; //Transfer enable flag receive (0=Enable Transfer/Ready, bit.2=bit.3 of otherside)	// A kind of acknowledge procedure
		else //(Bit.3, 0=Enable Transfer/Ready)
			value |= 4; //bit.2=1 (otherside is Not Ready)*/

		/*if (value & 1)
			value |= 0x02; //wireless always use 2Mhz speed right? this will fix MarioGolfAdv Not Detecting wireless*/

		if (rfu_polarity)
			value ^= 4;	// sometimes it's the other way around
		/*value &= 0xfffb;
		value |= (value & 1)<<2;*/

		#ifdef GBA_LOGGING
				if(systemVerbose & VERBOSE_LINK) {
					if(st != _T(""))
					log("%s\n", (LPCTSTR)st);
					logstartd = false;
					st = _T("");
					//st2 = _T(""); //st;
				}
		#endif

	default: //other SIO modes
		return value;
	}
}

u16 StartRFU3(u16 value)
{
	static char inbuffer[1032], outbuffer[1032];
	u16 *u16inbuffer = (u16*)inbuffer;
	u16 *u16outbuffer = (u16*)outbuffer;
	u32 *u32inbuffer = (u32*)inbuffer;
	u32 *u32outbuffer = (u32*)outbuffer;
	static int outsize, insize;
	//static int gbaid = 0;
	int initid = 0;
	int ngbas = 0;
	BOOL recvd = false;
	bool ok = false;

	switch (GetSIOMode(value, READ16LE(&ioMem[COMM_RCNT]))) {
	case NORMAL8:
		rfu_polarity = 0;
		return value;
		break;

	case NORMAL32:
		/*if (value & 8) //Transfer Enable Flag Send (bit.3, 1=Disable Transfer/Not Ready)
			value &= 0xfffb; //Transfer enable flag receive (0=Enable Transfer/Ready, bit.2=bit.3 of otherside)	// A kind of acknowledge procedure
		else //(Bit.3, 0=Enable Transfer/Ready)
			value |= 4; //bit.2=1 (otherside is Not Ready)*/

		if (value & 0x80) //start/busy bit
		{
			value |= 0x02; //wireless always use 2Mhz speed right?

			if ((value & 3) == 1) //internal clock w/ 256KHz speed
				rfu_transfer_end = 2048; //linktimeout; //rfu_transfer_end is not in ms but in clock ticks?
			else //external clock or any clock w/ 2MHz speed
				rfu_transfer_end = 256; //0;

			u16 a = READ16LE(&ioMem[COMM_SIODATA32_H]);

			switch (rfu_state) {
			case RFU_INIT:
				if (READ32LE(&ioMem[COMM_SIODATA32_L]) == 0xb0bb8001) {
					rfu_state = RFU_COMM;	// end of startup
					WaitForSingleObject(linksync[vbaid], linktimeout);
					c_s.Lock();
					ResetEvent(linksync[vbaid]);
					linkmem->rfu_q[vbaid] = 0;
					linkmem->rfu_qid[vbaid] = 0;
					linkmem->rfu_request[vbaid] = 0;
					linkmem->rfu_reqid[vbaid] = 0;
					linkmem->rfu_bdata[vbaid][0] = 0;
					linkmem->rfu_latency[vbaid] = -1;
					numtransfers = 0;
					rfu_masterq = 0;
					rfu_counter = 0; //is this needed?
					rfu_id = 0;
					gbaid = vbaid;
					gbaidx = gbaid;
					rfu_idx = 0;
					rfu_waiting = false;
					SetEvent(linksync[vbaid]); //vbaid
					c_s.Unlock();
				}
				/*if((value & 0x1081)==0x1080) { //Pre-initialization (used to detect whether wireless adapter is available or not)
					UPDATE_REG(COMM_SIODATA32_L, 0x494e); //0x494e
					UPDATE_REG(COMM_SIODATA32_H, 0x0000); //0x0000
					rfu_transfer_end = 256;
					transfer = 1;
					if (value & 8) //Transfer Enable Flag Send (bit.3, 1=Disable Transfer/Not Ready)
						value &= 0xfffb; //Transfer enable flag receive (0=Enable Transfer/Ready, bit.2=bit.3 of otherside)	// A kind of acknowledge procedure
					else //(Bit.3, 0=Enable Transfer/Ready)
						value |= 4; //bit.2=1 (otherside is Not Ready)
					value |= 0x02; // (value & 0xff7f)|0x02; //bit.1 need to be Set(2Mhz) otherwise some games might not be able to detect wireless adapter existance
					return value;
				} else*/ {
				UPDATE_REG(COMM_SIODATA32_H, READ16LE(&ioMem[COMM_SIODATA32_L]));
				UPDATE_REG(COMM_SIODATA32_L, a);
				}
				break;

			case RFU_COMM:
				if (a == 0x9966) //initialize command
				{
					WaitForSingleObject(linksync[vbaid], linktimeout); //wait until this gba allowed to move
					c_s.Lock();
					ResetEvent(linksync[vbaid]);
					linkmem->rfu_latency[vbaid] = (s32)lanlink.latency;
					SetEvent(linksync[vbaid]);
					c_s.Unlock();

					rfu_cmd = ioMem[COMM_SIODATA32_L];
					if ((rfu_qsend=ioMem[COMM_SIODATA32_L+1]) != 0) { //COMM_SIODATA32_L+1, following word size
						rfu_state = RFU_SEND;
						rfu_counter = 0;
					}
					if (rfu_cmd == 0x25 || rfu_cmd == 0x24 || rfu_cmd == 0x17) { //send data
						rfu_masterq = rfu_qsend;
					} else
					if(rfu_cmd == 0x16) { //init game room name
						rfu_masterq = rfu_qsend;
						memset(rfu_masterdata,0,sizeof(linkmem->rfu_bdata[vbaid])); //-4
					} /*else 
					if(rfu_cmd == 0xa8) { //seems to cause currently connected ID (rfu_id) to change while it's not suppose to
						WaitForSingleObject(linksync[vbaid], linktimeout); //wait until this gba allowed to move
						ResetEvent(linksync[vbaid]);
						if(linkmem->rfu_reqid[vbaid]==0) { //the host
							SetEvent(linksync[vbaid]);
							ok = true;
							linkmem->numgbas = lanlink.numgbas+1;
							initid = gbaid;
							do {
								gbaid++;
								gbaid %= linkmem->numgbas;
								if(gbaid!=vbaid) {
								WaitForSingleObject(linksync[gbaid], linktimeout); //wait until this gba allowed to move
								ResetEvent(linksync[gbaid]);
								ok = (linkmem->rfu_reqid[gbaid]!=(vbaid<<3)+0x61f1); //(gbaid!=initid && (gbaid==vbaid || linkmem->rfu_reqid[gbaid]!=(vbaid<<3)+0x61f1));
								SetEvent(linksync[gbaid]);
								} //else ok=(gbaid!=initid); //if(gbaid==initid) ok=false;
							} while (ok && (gbaid!=initid) && (linkmem->numgbas>1)); //only include connected gbas
							//if(!ok) rfu_id = (gbaid<<3)+0x61f1; //(u16)linkmem->rfu_bdata[gbaid][0];
							gbaid = initid; //to prevent changing rfu_id while it's not suppose to change
						} else { //not the host
							//rfu_id = linkmem->rfu_reqid[vbaid];
							//gbaid = (rfu_id-0x61f1)>>3;
						}
						SetEvent(linksync[vbaid]);
					}*/
					#ifdef GBA_LOGGING
						if(systemVerbose & VERBOSE_LINK) {
							log("CMD1 : %08X  %d  %04X %04X\n", READ32LE(&ioMem[COMM_SIODATA32_L]), GetTickCount(), rfu_id, gbaid);
						}
					#endif
					UPDATE_REG(COMM_SIODATA32_L, 0);
					UPDATE_REG(COMM_SIODATA32_H, 0x8000);
					/*if(rfu_cmd == 0xa8) { 
						rfu_polarity = 0; //not necessary, may cause the game to resend 0x8000 since the game will reverse the polarity after sending 0xa8 command
						//rfu_state = RFU_COMM;
					}*/
				}
				else if (a == 0x8000) //finalize command, the game may also send this when polarity reversed
				{
					switch (rfu_cmd) {
					case 0x1a:	// check if someone joined 
						rfu_qrecv = 0;
						ok = true;
						//log("GBAid : %08X %08X %d \n", gbaid, vbaid, GetTickCount());
						linkmem->numgbas = lanlink.numgbas+1;
						initid = gbaidx;
						do {
							gbaidx++;
							gbaidx %= linkmem->numgbas; //4 //most games need 4 players (including dummy players) before it starts communicating
							if(gbaidx!=vbaid) {
							WaitForSingleObject(linksync[gbaidx], linktimeout); //wait until this gba allowed to move
							c_s.Lock();
							ResetEvent(linksync[gbaidx]);
							ok = (linkmem->rfu_request[gbaidx]==0 || linkmem->rfu_reqid[gbaidx]!=(vbaid<<3)+0x61f1); //(gbaid!=initid && (gbaid==vbaid || (linkmem->rfu_request[gbaid]==0 || linkmem->rfu_reqid[gbaid]!=(vbaid<<3)+0x61f1)));
							SetEvent(linksync[gbaidx]);
							c_s.Unlock();
							} //else ok=(gbaid!=initid); //if(gbaid==initid) ok=false;
						} while (ok && (gbaidx!=initid) && (linkmem->numgbas>1)); //should include all gbas since we use dummy? //only include connected gbas
						if(linkmem->numgbas>1 && !(linkmem->rfu_request[gbaidx]==0 || linkmem->rfu_reqid[gbaidx]!=(vbaid<<3)+0x61f1)) { //Don't do anything if nobody joining
						//rfu_id = (gbaid<<3)+0x61f1;
						WaitForSingleObject(linksync[gbaidx], linktimeout); //wait until this gba allowed to move
						c_s.Lock();
						ResetEvent(linksync[gbaidx]);
						if(linkmem->rfu_request[gbaidx]!=0 && (linkmem->rfu_reqid[gbaidx]==(vbaid<<3)+0x61f1)) {
							rfu_masterdata[rfu_qrecv] = (gbaidx<<3)+0x61f1;
							rfu_qrecv++;
							//linkmem->rfu_request[gbaidx] = 0; //linkmem->rfu_request[gbaid]--; //to prevent receiving the same join request? //it seems the same join request need to be received more than once inorder to join successfully
						}
						SetEvent(linksync[gbaidx]);
						c_s.Unlock();
						}

						rfu_idx = 0;

						//if(rfu_qrecv==0 /*&& rfu_id!=0*/) { //use dummy reply for remaining players slot when a player joined, before the 1st player joined doesn't need dummy
						/*	rfu_masterdata[rfu_qrecv] = 0; //(vbaid<<3)+0x61f1; //0;
							rfu_qrecv++;

							//rfu_id = 0; //shouldn't do this?
							//gbaid = vbaid; //shouldn't do this?
						}*/

						if(rfu_qrecv!=0) {
							rfu_state = RFU_RECV;
							rfu_counter = 0;

							int tmpid = rfu_masterdata[rfu_qrecv-1];
							//int tmpgbaid = gbaid;
							if(tmpid>=0x61f1 && tmpid<=0xffff) { //(rfu_id!=0)
								rfu_id = tmpid;
								gbaid = (rfu_id-0x61f1)>>3;
								rfu_idx = rfu_id;
							}

							#ifdef GBA_LOGGING
								if(systemVerbose & VERBOSE_LINK) {
									log("CMDx1A : %08X %08X  %08X %08X %d \n", rfu_id, gbaid, rfu_masterdata[0], gbaidx, GetTickCount());
								}
							#endif
							//log("CMDx1A : %08X %08X %08X %08X %d \n", rfu_id, gbaid, vbaid, tmpgbaid, GetTickCount());
							rfu_waiting = false;
							//rfu_cmd |= 0x80; //rfu_cmd ^= 0x80 //Only invert the cmd when reply data is existed
						} /*else { //return value; //else rfu_waiting = true;
							rfu_id = 0;
							gbaid = vbaid;
						}*/
						rfu_cmd |= 0x80; //rfu_cmd ^= 0x80
						break;

					case 0x1b:	//Purge/Clear cache? Reset to after Initialization stage //Switch from Host to Join mode? //entering 'Ready' stage (after the 'Lobby' stage)?
						//stop broadcasting (room name / join request)
						WaitForSingleObject(linksync[vbaid], linktimeout);
						c_s.Lock();
						ResetEvent(linksync[vbaid]);
						linkmem->rfu_bdata[vbaid][0] = 0; //(vbaid<<3)+0x61f1; //room name id (0x16)
						//rfu_masterq = (sizeof(linkmem->rfu_bdata[vbaid])+3) >> 2; //
						//memcpy(&linkmem->rfu_bdata[vbaid][1],rfu_masterdata,(rfu_masterq << 2)-4);
						//memset(linkmem->rfu_bdata[vbaid], 0, (rfu_masterq << 2));
						linkmem->rfu_request[vbaid] = 0; //join request id (0x1f), is this suppose to be here? or is it at 0x1c/0x21?
						SetEvent(linksync[vbaid]);
						c_s.Unlock();
						//clearing data buffer to prevent having mixed up data with data from different/previous stage
						for(int i=0;i<linkmem->numgbas;i++) 
						if(i!=vbaid) {
							LinkDiscardData(i);
							linkmem->rfu_q[i] = 0;
						}
						//if((s32)rfu_masterdata[0]==0)
						//		log("CMDx%02X : %08X %08X  %08X %d \n", rfu_cmd, rfu_id, gbaid, (s32)rfu_masterdata[0], GetTickCount());

						rfu_cmd |= 0x80; //rfu_cmd ^= 0x80
						break;

					case 0x1c:	//Stop broadcasting join request ? or Refresh room data(s) in the adapter ??
						WaitForSingleObject(linksync[vbaid], linktimeout); //wait until the last sent data has been received/read
						c_s.Lock();
						ResetEvent(linksync[vbaid]); //lock
						linkmem->rfu_request[vbaid] = 0; //4; //1 = id data is fresh/not received by server yet
						SetEvent(linksync[vbaid]); //unlock
						c_s.Unlock();
						rfu_cmd |= 0x80; //rfu_cmd ^= 0x80
						break;

					case 0x1e:	//Switch from Join to Host mode? //receive broadcast data (select a room)
					case 0x1d:	//Read room list data //no visible difference
						rfu_polarity = 0;
						rfu_state = RFU_RECV;
						rfu_counter = 0;
						rfu_qrecv = 0; //7*(linkmem->numgbas-1);
						//int ctr = 0;
						for(int i=0; i<linkmem->numgbas; i++) 
						if(i!=vbaid) { //linkmem->numgbas is the same as lanlink.numgbas-1 ?
							WaitForSingleObject(linksync[i], linktimeout); //wait until this gba allowed to move
							c_s.Lock();
							ResetEvent(linksync[i]); //don't allow this gba to move (send data)
							if(linkmem->rfu_bdata[i][0]!=0) 
							//if(linkmem->rfu_gdata[i]==linkmem->rfu_gdata[vbaid]) //only matching game id will be shown
							{
								rfu_masterq = (sizeof(linkmem->rfu_bdata[i])+3) >> 2;
								memcpy(&rfu_masterdata[rfu_qrecv],linkmem->rfu_bdata[i], rfu_masterq << 2);
								rfu_qrecv += rfu_masterq; //sizeof(linkmem->rfu_bdata[i]);
								//rfu_qrecv = (rfu_qrecv+3) >> 2; //ceil(rfu_qrecv/4)
							}
							SetEvent(linksync[i]);
							c_s.Unlock();
						}
						/*linkmem->numgbas = lanlink.numgbas+1;
						initid = roomid;
						ok = true;
						do {
							roomid++;
							roomid %= linkmem->numgbas;
							if(roomid!=vbaid) {
								WaitForSingleObject(linksync[roomid], linktimeout); //wait until this gba allowed to move
								ResetEvent(linksync[roomid]); //don't allow this gba to move (send data)
								if(linkmem->rfu_bdata[roomid][0]!=0) {
									rfu_masterq = (sizeof(linkmem->rfu_bdata[roomid])+3) >> 2;
									memcpy(&rfu_masterdata[rfu_qrecv],linkmem->rfu_bdata[roomid], rfu_masterq << 2);
									rfu_qrecv += rfu_masterq; //sizeof(linkmem->rfu_bdata[i]);
									ok = false;
								}
								SetEvent(linksync[roomid]);
							}
						} while  (ok && (roomid!=initid) && (linkmem->numgbas>1));*/ //only include connected gbas
						if(rfu_qrecv==0) { //using dummy data to prevent some games from reseting RFU when no data received
							rfu_masterq = 7;
							memset(&rfu_masterdata[rfu_qrecv], 0, rfu_masterq << 2);
							rfu_qrecv += rfu_masterq;
						}
						//if(rfu_qrecv!=0)
						rfu_cmd |= 0x80; //rfu_cmd ^= 0x80
						break;

					case 0x14:	// unknown, seems to have something to do with 0x11 ? (0=error)
						//Invalid signal detecetd, Reset signal data
						//TODO: To prevent Pokemon Union room from looping 0x11 and 0x14 for infinity when another player tried to talk with this player
						/*WaitForSingleObject(linksync[gbaid], linktimeout);
						ResetEvent(linksync[gbaid]);
						linkmem->rfu_latency[gbaid] = -1; //shouldn't reset? seems to cause MarioGoldAdvTour getting disconnected
						SetEvent(linksync[gbaid]); //vbaid*/
						//rfu_id = 0; //Reset here may cause MArio Golf Adv Tour tried to read (0x26) even when 0x11 returned 0 (no signal) which make it tries to read it's own sent data (gbaid = vbaid)
						//gbaid = vbaid;

						if(rfu_id==0) rfu_masterdata[0] = 0; else
						rfu_masterdata[0] = 0x1fff; //(vbaid<<3)+0x61f1; //signstr = 0xff; //last signal/error code? or timeout value?(higher seems to be more stable)
						rfu_qrecv = 1;//0
						rfu_state = RFU_RECV;

						//if((s32)rfu_masterdata[0]==0)
								log("CMDx%02X : %08X %08X  %08X %d \n", rfu_cmd, rfu_id, gbaid, (s32)rfu_masterdata[0], GetTickCount());

						rfu_cmd |= 0x80; //rfu_cmd ^= 0x80
						break;

					case 0x13:	//Get Last Error Code // unknown, seems to have something to do with 0x11 ? //vendor id? or this adapter id?
						//TODO: To find out why sometimes the game failed to detect a player leaving a room (the game still showing the leaving player while that player is nolonger connected) on Mario Golf Adv Tour
						//if(rfu_id==0) rfu_masterdata[0] = 0; else
						rfu_masterdata[0] = 0xfff; //0xffff; //(vbaid<<3)+0x61f1; //signstr = 0xff; //last signal/error code? or timeout value?(higher seems to be more stable, and 0=error)
						rfu_qrecv = 1;//0
						rfu_state = RFU_RECV;

						//if((s32)rfu_masterdata[0]==0)
						//		log("CMDx%02X : %08X %08X %d %d \n", rfu_cmd, rfu_id, gbaid, (s32)rfu_masterdata[0], GetTickCount());

						rfu_cmd |= 0x80; //rfu_cmd ^= 0x80
						break;

					case 0x11:	//read signal strength (0=error) //? always receives 0xff - I suspect it's something for 3+ players
						//the otherside must send the signal, so this GBA know if the otherside have been disconnected or not
						u16 signstr;
						s32 lat;
						rfu_qrecv = 1;//0;
						/*if(rfu_qrecv==0) { //not the host
							rfu_qrecv++;
						}*/
						if(rfu_qrecv!=0) {
							rfu_state = RFU_RECV;
							if(gbaid==vbaid) lat = (u32)(s32)-1; else {
							WaitForSingleObject(linksync[gbaid], linktimeout); //wait
							c_s.Lock();
							ResetEvent(linksync[gbaid]); //lock
							lat = linkmem->rfu_latency[gbaid];
							SetEvent(linksync[gbaid]); //unlock
							c_s.Unlock();
							}
							if(rfu_id==0 || lat<0 /*|| rfu_idx==0*/) signstr = 0; else // no-signal/drop the connection
							if(lat<50) signstr = 0x00ff; else // 0xff=4/4bars
							if(lat<100) signstr = 0x007f; else // 0x7f=3/4bars
							if(lat<200) signstr = 0x003f; else // 0x3f=2/4bars
							if(lat<400) signstr = 0x001f; else // 0x1f=2/4bars
							if(lat<800) signstr = 0x000f; else signstr = 0x0007; // 1-0xf=1/4bars
							rfu_masterdata[0] = signstr;

							//if((s32)rfu_masterdata[0]==0 && rfu_id!=0)
							//	log("CMDx%02X : %08X %08X %d %d \n", rfu_cmd, rfu_id, gbaid, (s32)rfu_masterdata[0], GetTickCount());

							if(signstr==0) { //to prevent 0x1a from using dummy when players no longer joined
								rfu_id = 0;
								gbaid = vbaid;
								//gbaidx = gbaid;
								//rfu_idx = 0;
							}
						}
						rfu_cmd |= 0x80; //rfu_cmd ^= 0x80
						break;

					case 0x20:	//Start broadcasting join request? //this has something to do with 0x1f
						WaitForSingleObject(linksync[vbaid], linktimeout); //wait until the last sent data has been received/read
						c_s.Lock();
						ResetEvent(linksync[vbaid]); //lock
						linkmem->rfu_request[vbaid] = 1; //4; //true, 1 = id data is fresh/not received by server yet
						SetEvent(linksync[vbaid]); //unlock
						c_s.Unlock();

						rfu_masterdata[0] = 0x641b; //(vbaid<<3)+0x61f1 //max adapter id?

						//Should this reply with High(16bit) = non-zero until the host no longer broadcasting their room? (to prevent client from waiting data (0x27) before the host ready to send the data)
						WaitForSingleObject(linksync[gbaid], linktimeout); //wait until the last sent data has been received/read
						c_s.Lock();
						ResetEvent(linksync[gbaid]); //lock
						if(linkmem->rfu_bdata[gbaid][0]!=0) rfu_masterdata[0] = (u32)-1; //0xffffffff; //host still broadcasting
						SetEvent(linksync[gbaid]); //unlock
						c_s.Unlock();

						rfu_cmd |= 0x80; //rfu_cmd ^= 0x80
						rfu_polarity = 0;
						rfu_state = RFU_RECV;
						rfu_qrecv = 1;
						break;

					case 0x21:	//Start(or stop?) broadcasting join request? //this has something to do with 0x1f // this too
						/*WaitForSingleObject(linksync[vbaid], linktimeout); //wait until the last sent data has been received/read
						ResetEvent(linksync[vbaid]); //lock
						linkmem->rfu_request[vbaid] = 1; //0; //4; //1 = id data is fresh/not received by server yet
						SetEvent(linksync[vbaid]);*/ //unlock

						rfu_masterdata[0] = 0x641b; //(vbaid<<3)+0x61f1 //max adapter id?
						rfu_cmd |= 0x80; //rfu_cmd ^= 0x80
						rfu_polarity = 0;
						rfu_state = RFU_RECV;
						rfu_qrecv = 1;
						break;

					case 0x24:	// send data (to currently connected adapter) //(broadcast to all connected adapters?)
						//u16 tmpid, idmask;
						//u8 tmpq;
						//DWORD tmpTime;
						/*WaitForSingleObject(linksync[vbaid], linktimeout); //wait until the last sent data has been received/read
						ResetEvent(linksync[vbaid]); //lock
						tmpid = linkmem->rfu_qid[vbaid];
						tmpq = linkmem->rfu_q[vbaid];
						SetEvent(linksync[vbaid]); //unlock
						if(tmpq!=0 && (tmpid<0x61f1 && !(tmpid & (1<<gbaid)))) {
							log("CMDx%02X : %08X %08X %02X %04X %d \n", rfu_cmd, rfu_id, gbaid, tmpq, tmpid, GetTickCount());
							return value; //should not reply with 0x80000000 yet
						}*/
						if((numtransfers++)==0) linktime = 1; //numtransfers doesn't seems to be used?
						/*linkmem->numgbas = lanlink.numgbas+1;
						idmask = (0xffff>>(16-linkmem->numgbas))^(1<<vbaid);
						ok = true;
						tmpTime = GetTickCount();
						if (gbaid!=vbaid) //to prevent loop for infinity waiting for it's self to read previous data
						do { //waiting for data to be received may cause a slowdown if the otherside rarely use 0x26 (ie. still waiting for players to join)
							DWORD tmpTime2 = GetTickCount();
							if((tmpTime2-tmpTime)>=5000) {
								log("DATx%02X : %08X  %d  %04X %04X  Waiting Data %04X %02X  %04X %02X\n", rfu_cmd, READ32LE(&ioMem[COMM_SIODATA32_L]), GetTickCount(), rfu_id, gbaid, linkmem->rfu_qid[gbaid], linkmem->rfu_q[gbaid], linkmem->rfu_qid[vbaid], linkmem->rfu_q[vbaid]);
								tmpTime = tmpTime2;
							}
							WaitForSingleObject(linksync[vbaid], linktimeout); //wait until the last sent data has been received/read to make sure previous data aren't lost
							ResetEvent(linksync[vbaid]); //lock
							tmpid = linkmem->rfu_qid[vbaid];
							tmpq = linkmem->rfu_q[vbaid];
							SetEvent(linksync[vbaid]); //unlock
							ok=(tmpq!=0 && (tmpid<0x61f1 && !((tmpid & idmask)==idmask))); //(tmpq!=0 && (tmpid<0x61f1 && !(tmpid & (1<<gbaid))));
							//if(tmpid==vbaid || gbaid==vbaid) break;
						} while (ok && linkmem->numgbas>1);
						WaitForSingleObject(linksync[vbaid], linktimeout);
						ResetEvent(linksync[vbaid]); //mark it as unread/unreceived data
						linkmem->rfu_linktime[vbaid] = linktime;
						linkmem->rfu_q[vbaid] = rfu_masterq; //linkmem->rfu_q[vbaid];
						memcpy(linkmem->rfu_data[vbaid],rfu_masterdata,rfu_masterq<<2);
						linkmem->rfu_qid[vbaid] = (gbaid<<3)+0x61f1; //rfu_id; //0; //rfu_id; //mark the id to whom the data for, 0=broadcast to all connected gbas
						SetEvent(linksync[vbaid]);*/
						outbuffer[1] = 0x80|gbaid; //'W';
						outbuffer[0] = (rfu_masterq+1)<<2; //total size including headers //vbaid;
						outbuffer[2] = rfu_cmd;
						outbuffer[3] = rfu_masterq;
						memcpy(&outbuffer[4],rfu_masterdata,rfu_masterq<<2); //data size (excluding headers)
						if(gbaid!=vbaid)
						LinkSendData(outbuffer, (rfu_masterq+1)<<2, RetryCount, gbaid);
						//log("Send%02X[%d] : %02X  %0s\n", rfu_cmd, GetTickCount(), rfu_masterq*4, (LPCTSTR)DataHex((char*)rfu_masterdata,rfu_masterq*4) );
						rfu_cmd |= 0x80; //rfu_cmd ^= 0x80
						linktime = 0;
						//LinkWaitForData(linktimeout,NULL); //to prevent flooding the socket's buffer
						break;

					case 0x25:	// send (to currently connected adapter) & wait for data reply
						/*WaitForSingleObject(linksync[vbaid], linktimeout); //wait until the last sent data has been received/read
						ResetEvent(linksync[vbaid]); //lock
						tmpid = linkmem->rfu_qid[vbaid];
						tmpq = linkmem->rfu_q[vbaid];
						SetEvent(linksync[vbaid]); //unlock
						if(tmpq!=0 && (tmpid<0x61f1 && !(tmpid & (1<<gbaid)))) {
							log("CMDx%02X : %08X %08X %02X %04X %d \n", rfu_cmd, rfu_id, gbaid, tmpq, tmpid, GetTickCount());
							return value; //should not reply with 0x80000000 yet
						}*/
						if((numtransfers++)==0) linktime = 1; //numtransfers doesn't seems to be used?
						/*linkmem->numgbas = lanlink.numgbas+1;
						idmask = (0xffff>>(16-linkmem->numgbas))^(1<<vbaid);
						ok = true;
						tmpTime = GetTickCount();
						if (gbaid!=vbaid) //to prevent loop for infinity waiting for it's self to read previous data
						do { //waiting for data to be received may cause a slowdown if the otherside rarely use 0x26 (ie. still waiting for players to join)
							DWORD tmpTime2 = GetTickCount();
							if((tmpTime2-tmpTime)>=5000) {
								log("DATx%02X : %08X  %d  %04X %04X  Waiting Data %04X %02X  %04X %02X\n", rfu_cmd, READ32LE(&ioMem[COMM_SIODATA32_L]), GetTickCount(), rfu_id, gbaid, linkmem->rfu_qid[gbaid], linkmem->rfu_q[gbaid], linkmem->rfu_qid[vbaid], linkmem->rfu_q[vbaid]);
								tmpTime = tmpTime2;
							}
							WaitForSingleObject(linksync[vbaid], linktimeout); //wait until the last sent data has been received/read to make sure previous data aren't lost
							ResetEvent(linksync[vbaid]); //lock
							tmpid = linkmem->rfu_qid[vbaid]; //target id
							tmpq = linkmem->rfu_q[vbaid];
							SetEvent(linksync[vbaid]); //unlock
							ok=(tmpq!=0 && (tmpid<0x61f1 && !((tmpid & idmask)==idmask))); //(tmpq!=0 && (tmpid<0x61f1 && !(tmpid & (1<<gbaid))));
							//if(tmpid==vbaid || gbaid==vbaid) break;
						} while (ok && linkmem->numgbas>1);
						WaitForSingleObject(linksync[vbaid], linktimeout);
						ResetEvent(linksync[vbaid]); //mark it as unread/unreceived
						linkmem->rfu_linktime[vbaid] = linktime;
						linkmem->rfu_q[vbaid] = rfu_masterq; //linkmem->rfu_q[vbaid];
						memcpy(linkmem->rfu_data[vbaid],rfu_masterdata,rfu_masterq<<2); //(rfu_counter+1)<<2 //linkmem->rfu_q[vbaid]<<2 //rfu_qsend<<2
						linkmem->rfu_qid[vbaid] = (gbaid<<3)+0x61f1; //rfu_id; //mark the id to whom the data for, 0=broadcast to all connected gbas
						SetEvent(linksync[vbaid]);*/
						outbuffer[1] = 0x80|gbaid; //'W';
						outbuffer[0] = (rfu_masterq+1)<<2; //total size including headers //vbaid;
						outbuffer[2] = rfu_cmd;
						outbuffer[3] = rfu_masterq;
						memcpy(&outbuffer[4],rfu_masterdata,rfu_masterq<<2); //data size (excluding headers)
						if(gbaid!=vbaid)
						LinkSendData(outbuffer, (rfu_masterq+1)<<2, RetryCount, gbaid);
						//log("Send%02X[%d] : %02X  %0s\n", rfu_cmd, GetTickCount(), rfu_masterq*4, (LPCTSTR)DataHex((char*)rfu_masterdata,rfu_masterq*4) );
						rfu_cmd |= 0x80; //rfu_cmd ^= 0x80
						//if(gbaid!=vbaid) 
						//LinkWaitForData(linktimeout,NULL); //to prevent flooding the socket's buffer
						break;

					case 0x26: //receive data
						//TODO: to check why sometimes there is no data in the buffer while 0x25/0x27 were able to detect incoming data, may be the data removed before being read
						//read data from currently connected adapter
						//LinkWaitForData(linktimeout,NULL); //to prevent flooding the socket's buffer
						/*if(rfu_wastimeout) {
						tmpTime = GetTickCount();
						do {
							DWORD tmpTime2 = GetTickCount();
							if((tmpTime2-tmpTime)>=5000) {
								log("DATx%02X : %08X  %d  %04X %04X  Waiting Data %04X %02X  %04X %02X\n", rfu_cmd, READ32LE(&ioMem[COMM_SIODATA32_L]), GetTickCount(), rfu_id, gbaid, linkmem->rfu_qid[gbaid], linkmem->rfu_q[gbaid], linkmem->rfu_qid[vbaid], linkmem->rfu_q[vbaid]);
								tmpTime = tmpTime2;
							}
							WaitForSingleObject(linksync[gbaid], linktimeout); //wait until data become available
							ResetEvent(linksync[gbaid]); //lock
							tmpid = linkmem->rfu_qid[gbaid];
							tmpq = linkmem->rfu_q[gbaid];
							SetEvent(linksync[gbaid]); //unlock
						} while (tmpq==0 || (tmpid<0x61f1 && (tmpid & (1<<vbaid))));
						rfu_wastimeout = false;
						}*/
						rfu_qrecv = 0;
						if(gbaid!=vbaid) { //don't read it's own data
						//WaitForSingleObject(linksync[gbaid], linktimeout);
						c_s.Lock();
						//ResetEvent(linksync[gbaid]); //lock, to prevent data being changed while still being read
						if((linkmem->rfu_qid[gbaid]==(vbaid<<3)+0x61f1)||(linkmem->rfu_qid[gbaid]<0x61f1 && !(linkmem->rfu_qid[gbaid] & (1<<vbaid)))) { //only receive data intended for this gba
							rfu_masterq = linkmem->rfu_q[gbaid];
							memcpy(rfu_masterdata, linkmem->rfu_data[gbaid], rfu_masterq<<2); //128 //sizeof(rfu_masterdata)
						} else rfu_masterq = 0;
						//SetEvent(linksync[gbaid]); //unlock
						c_s.Unlock();
						rfu_qrecv = rfu_masterq; //rfu_cacheq;
						}

						if(rfu_qrecv!=0)
						{
							//WaitForSingleObject(linksync[gbaid], linktimeout);
							c_s.Lock();
							//ResetEvent(linksync[gbaid]);
							if(linkmem->rfu_qid[gbaid]>=0x61f1) //only when the data intended for this gba
							linkmem->rfu_q[gbaid] = 0; else linkmem->rfu_qid[gbaid] |= (1<<vbaid); //to prevent receiving an already received data
							//SetEvent(linksync[gbaid]);
							c_s.Unlock();
							rfu_state = RFU_RECV;
							rfu_counter = 0;
							//rfu_cmd |= 0x80; //rfu_cmd ^= 0x80
						} //else log("CMDx%02X : %04X %04X %02X %d \n", rfu_cmd, rfu_id, gbaid, linkmem->rfu_q[gbaid], GetTickCount());
						rfu_cmd |= 0x80; //rfu_cmd ^= 0x80
						break;
					
					case 0x30: //Terminate connection? Reset state to after Initialization? (just like 0x1b)
						//TODO: Prevent MarioGolfAdvTour/Pokemon Union room from changing Host<->Join mode even after player joined
						//log("CMDx30 : %08X %08X %d %04X\n", rfu_id, gbaid, GetTickCount(), vbaid);
						//for(int i=0; i<=lanlink.numgbas; i++) LinkDiscardData(i);
						//WaitForSingleObject(linksync[vbaid], linktimeout);
						c_s.Lock();
						ResetEvent(linksync[vbaid]);
						//linkmem->rfu_q[vbaid] = 0;
						//linkmem->rfu_qid[vbaid] = 0;
						linkmem->rfu_request[vbaid] = 0;
						linkmem->rfu_reqid[vbaid] = 0;
						linkmem->rfu_bdata[vbaid][0] = 0;
						linkmem->rfu_gdata[vbaid] = 0;
						//linkmem->rfu_latency[vbaid] = -1; //shouldn't reset? seems to cause MarioGoldAdvTour getting disconnected
						SetEvent(linksync[vbaid]); //vbaid
						c_s.Unlock();
						numtransfers = 0;
						rfu_masterq = 0;
						rfu_polarity = 0; //is this included?
						//gbaid = vbaid; //shouldn't reset?
						//gbaidx = gbaid;
						//rfu_idx = 0;
						//rfu_id = 0; //shouldn't reset?
						rfu_waiting = false;

						//if((s32)rfu_masterdata[0]==0)
								log("CMDx%02X : %08X %08X  %08X %d \n", rfu_cmd, rfu_id, gbaid, (s32)rfu_masterdata[0], GetTickCount());

						rfu_cmd |= 0x80; //rfu_cmd ^= 0x80
						break;

					case 0xee: //resend last command?
						rfu_cmd ^= 0x80; //rfu_cmd ^= 0x80
						break;

					case 0x16:	//Set a game room name //send broadcast data (ie. broadcast room name)
						//copy bdata to all gbas
						{
							rfu_masterq = (sizeof(linkmem->rfu_bdata[vbaid]) >> 2)-1; //(sizeof(linkmem->rfu_bdata[vbaid])+3) >> 2; //7 dwords
							/*WaitForSingleObject(linksync[vbaid], linktimeout);
							c_s.Lock();
							ResetEvent(linksync[vbaid]);
							//linkmem->rfu_bdata[vbaid][0] = (vbaid<<3)+0x61f1; //client id who want to join a host //shouldn't broadcast it yet?
							memcpy(&linkmem->rfu_bdata[vbaid][1],rfu_masterdata,(rfu_masterq) << 2); //only use 6 dwords for the name (since 1st dwords used for ID)
							SetEvent(linksync[vbaid]);
							c_s.Unlock();*/
							outbuffer[1] = 0x80|gbaid; //'W';
							outbuffer[0] = (rfu_masterq+1)<<2; //total size including headers //vbaid;
							outbuffer[2] = rfu_cmd;
							outbuffer[3] = rfu_masterq;
							memcpy(&outbuffer[4],rfu_masterdata,rfu_masterq<<2); //data size (excluding headers)
							//if(gbaid!=vbaid)
							LinkSendData(outbuffer, (rfu_masterq+1)<<2, RetryCount, 0); //broadcast
						}
						rfu_cmd |= 0x80; //rfu_cmd ^= 0x80
						break;

					case 0x17:	// setup or something ? (broadcast game id?)
						//copy gdata to all gbas
						{
							/*WaitForSingleObject(linksync[vbaid], linktimeout);
							c_s.Lock();
							ResetEvent(linksync[vbaid]);
							linkmem->rfu_gdata[vbaid] = rfu_masterdata[0];
							SetEvent(linksync[vbaid]);
							c_s.Unlock();*/
							outbuffer[1] = 0x80|gbaid; //'W';
							outbuffer[0] = 8; //vbaid;
							outbuffer[2] = rfu_cmd;
							outbuffer[3] = rfu_masterq; //1;
							//u32outbuffer[1] = rfu_masterdata[0];
							memcpy(&u32outbuffer[1], rfu_masterdata, rfu_masterq<<2);
							if(gbaid!=vbaid)
							LinkSendData(outbuffer, 8, RetryCount, gbaid);
							//#ifdef GBA_LOGGING
							//	if(systemVerbose & VERBOSE_LINK) {
									log("CMDx17 : %08X %08X %08X %d \n", rfu_id, gbaid, rfu_masterdata[0], GetTickCount());
							//	}
							//#endif
						}
						rfu_cmd |= 0x80; //rfu_cmd ^= 0x80
						break;

					case 0x1f:	// pick/join a server
						/*WaitForSingleObject(linksync[vbaid], linktimeout);
						ResetEvent(linksync[vbaid]);
						linkmem->rfu_reqid[vbaid] = rfu_masterdata[0]; //(rfu_id-0x61f1)>>3
						//linkmem->rfu_request[vbaid] = 1; //4; //true, id data is fresh/not received by server yet
						SetEvent(linksync[vbaid]);*/
						rfu_id = rfu_masterdata[0];
						gbaid = (rfu_id-0x61f1)>>3;
						rfu_idx = rfu_id;
						gbaidx = gbaid;
						outbuffer[1] = 0x80|gbaid; //'W';
						outbuffer[0] = 8; //vbaid;
						outbuffer[2] = rfu_cmd;
						outbuffer[3] = 1;
						u32outbuffer[1] = rfu_id;
						if(gbaid!=vbaid)
						LinkSendData(outbuffer, 8, RetryCount, gbaid);
						rfu_cmd |= 0x80; //rfu_cmd ^= 0x80
						break;

					case 0x10:	// init?
					case 0x3d:	// init?
						LinkDiscardData(0); //for(int i=0; i<=lanlink.numgbas; i++) LinkDiscardData(i);
						WaitForSingleObject(linksync[vbaid], linktimeout);
						c_s.Lock();
						ResetEvent(linksync[vbaid]);
						linkmem->rfu_q[vbaid] = 0;
						linkmem->rfu_qid[vbaid] = 0;
						linkmem->rfu_request[vbaid] = 0;
						linkmem->rfu_reqid[vbaid] = 0;
						linkmem->rfu_bdata[vbaid][0] = 0;
						linkmem->rfu_gdata[vbaid] = 0;
						linkmem->rfu_latency[vbaid] = -1;
						SetEvent(linksync[vbaid]); //vbaid
						c_s.Unlock();
						numtransfers = 0;
						rfu_masterq = 0;
						gbaid = vbaid;
						gbaidx = gbaid;
						rfu_idx = 0;
						rfu_id = 0;
						rfu_waiting = false;

						rfu_masterdata[0] = (vbaid<<3)+0x61f1; //this adapter id?

						rfu_qrecv = 1;
						rfu_state = RFU_RECV;
						rfu_cmd |= 0x80; //rfu_cmd ^= 0x80
						break;

					case 0x19:	//Start broadcasting game room name?
						{
							/*WaitForSingleObject(linksync[vbaid], linktimeout);
							c_s.Lock();
							ResetEvent(linksync[vbaid]);
							linkmem->rfu_bdata[vbaid][0] = (vbaid<<3)+0x61f1; 
							//rfu_masterq = (sizeof(linkmem->rfu_bdata[vbaid])+3) >> 2; //
							//memcpy(&linkmem->rfu_bdata[vbaid][1],rfu_masterdata,(rfu_masterq << 2)-4);
							SetEvent(linksync[vbaid]);
							c_s.Unlock();*/
							outbuffer[1] = 0x80|gbaid; //'W';
							outbuffer[0] = 8; //vbaid;
							outbuffer[2] = rfu_cmd;
							outbuffer[3] = 1;
							u32outbuffer[1] = (vbaid<<3)+0x61f1; //rfu_masterdata[0];
							//if(gbaid!=vbaid)
							LinkSendData(outbuffer, 8, RetryCount, 0); //broadcast
						}
						rfu_cmd |= 0x80; //rfu_cmd ^= 0x80
						break;

					case 0x27:	// wait for data ? the game(digimon) might be using 2.4sec timeout (2-2.5sec)
						//LinkWaitForData(linktimeout,NULL); //to prevent flooding the socket's buffer
						/*//rfu_transfer_end = 0;
						ok = false;
						for(int i=0; i<linkmem->numgbas; i++)
							if(i!=vbaid) {
								WaitForSingleObject(linksync[i], linktimeout);
								ResetEvent(linksync[i]);
								if(linkmem->rfu_q[i]>0 && ((linkmem->rfu_qid[i]&(1<<vbaid))==0||(linkmem->rfu_qid[i]==(vbaid<<3)+0x61f1))) {ok=true;SetEvent(linksync[i]);break;}
								SetEvent(linksync[i]);
							}

						#ifdef GBA_LOGGING
						if(systemVerbose & VERBOSE_LINK) {
							if(!ok)
							log("CMDx%02X : %08X  %d  %04X %04X  Waiting Data\n", rfu_cmd, READ32LE(&ioMem[COMM_SIODATA32_L]), GetTickCount(), rfu_id, gbaid); else
							log("CMDx%02X : %08X  %d  %04X %04X  Data Existed\n", rfu_cmd, READ32LE(&ioMem[COMM_SIODATA32_L]), GetTickCount(), rfu_id, gbaid);
						}
						#endif
						
						if(!ok) return value; //prevent the game from sending more commands while waiting for reply data (doesn't stop code executions)
						//if(ok)*/ 
						rfu_cmd |= 0x80; //rfu_cmd ^= 0x80
						//if(gbaid!=vbaid) 
						//LinkWaitForData(linktimeout,NULL);
						break;

					default:
						rfu_cmd |= 0x80; //rfu_cmd ^= 0x80
						break;

					case 0xa5:	//	2nd part of send&wait function 0x25
					case 0xa7:	//	2nd part of wait function 0x27
						//rfu_polarity = 1; //reversing polarity will make the game to send 0x80000000 and expecting 0x99660028 in return
						//rfu_cmd = 0x28;
						/*//int i = 0;
						ok = false;
						do {
						for(int i=0; i<linkmem->numgbas; i++)
							if(i!=vbaid) {
								WaitForSingleObject(linksync[i], linktimeout);
								ResetEvent(linksync[i]);
								if(linkmem->rfu_q[i]>0 && ((linkmem->rfu_qid[i]&(1<<vbaid))==0||(linkmem->rfu_qid[i]==(vbaid<<3)+0x61f1))) {ok=true;SetEvent(linksync[i]);break;}
								SetEvent(linksync[i]);
							}
						} while (!ok && linkmem->numgbas>1);*/

					//case 0x28:
						/*if (linkid == -1) {
							linkid++; vbaid = linkid;
							WaitForSingleObject(linksync[vbaid], linktimeout);
							c_s.Lock();
							ResetEvent(linksync[vbaid]); //lock, to make sure nobody changing it until it finishes reading it
							linkmem->rfu_linktime[vbaid] = 0;
							SetEvent(linksync[vbaid]); //unlock
							c_s.Unlock();
						}
						if (linkid && linkmem->rfu_request[gbaid] == 0) {
							WaitForSingleObject(linksync[gbaid], linktimeout);
							c_s.Lock();
							ResetEvent(linksync[gbaid]); //lock
							linkmem->rfu_q[gbaid] = 0;
							SetEvent(linksync[gbaid]); //unlock
							c_s.Unlock();
							rfu_transfer_end = 256;
							rfu_polarity = 1;
							rfu_cmd = 0x28; //is this command 0x29 existed?
							linktime = 0;
							break;
						}*/
						if(rfu_transfer_end<=0) {
							rfu_transfer_end = 256;
							rfu_polarity = 1;
							rfu_cmd = 0x28;
							linktime = 0;
							break;
						}
						if ((numtransfers++) == 0)
							linktime = 0;

						//WaitForSingleObject(linksync[gbaid], linktimeout);
						c_s.Lock();
						//ResetEvent(linksync[gbaid]); //lock, to make sure nobody changing it until it finishes reading it
						rfu_transfer_end = linkmem->rfu_linktime[gbaid] - linktime + 256; //[vbaid]
						//SetEvent(linksync[gbaid]); //unlock
						c_s.Unlock();

						if (rfu_transfer_end < 256) //is this needed?
							rfu_transfer_end = 256; //

						linktime = -rfu_transfer_end;
						//rfu_transfer_end = 2048; //linktimeout; //256 //0 //0 might fasten the response (but slowdown performance), but if incoming data isn't ready the game might get timeout faster
						//rfu_polarity = 1;
						rfu_lasttime = GetTickCount();
						//check if there is incoming data for this gba
						if(rfu_cmd==0xa5) { 
						//do { 
						//LinkWaitForData(linktimeout,NULL); //to prevent flooding the socket's buffer
						//int i = 0;
						ok = false;
						for(int i=0; i<linkmem->numgbas; i++)
							if(i!=vbaid) {
								//WaitForSingleObject(linksync[i], linktimeout);
								c_s.Lock();
								//ResetEvent(linksync[i]);
								if(linkmem->rfu_q[i]>0 && ((linkmem->rfu_qid[i]&(1<<vbaid))==0||(linkmem->rfu_qid[i]==(vbaid<<3)+0x61f1))) {ok=true;c_s.Unlock();break;} //SetEvent(linksync[i]);
								//SetEvent(linksync[i]); 
								c_s.Unlock();
								//if(!ok && lanlink.connected && !EmuReseted) SleepEx(1,true);
							}
						//} while (!ok && lanlink.connected && !EmuReseted && linkmem->numgbas>1 && (GetTickCount()-rfu_lasttime)>=linktimeout);
						}
						//#ifdef GBA_LOGGING
						//if(systemVerbose & VERBOSE_LINK) {
						//	if(!ok)
						//	log("CMDx%02X : %08X  %d  %04X %04X  Waiting Data\n", rfu_cmd, READ32LE(&ioMem[COMM_SIODATA32_L]), GetTickCount(), rfu_id, gbaid); //else
						//	log("CMDx%02X : %08X  %d  %04X %04X  Data Existed %04X %02X\n", rfu_cmd, READ32LE(&ioMem[COMM_SIODATA32_L]), GetTickCount(), rfu_id, gbaid, i, linkmem->rfu_q[i]);
						//}
						//#endif
						
						//if(!ok ) return value; //&& rfu_cmd!=0x28 //don't change anything yet if there is no incoming data
						if(ok) {
							rfu_polarity = 1; //reversing polarity will make the game to send 0x80000000 and expecting 0x99660028 in return
							rfu_cmd = 0x28;
						}
						break;
					}

					//if(rfu_waiting) return value; //Prevent the game from sending more commands, Don't do anything when waiting for reply data to be ready

					UPDATE_REG(COMM_SIODATA32_H, 0x9966);
					UPDATE_REG(COMM_SIODATA32_L, (rfu_qrecv<<8) | rfu_cmd);
					
					#ifdef GBA_LOGGING
						if(systemVerbose & VERBOSE_LINK) {
							static CString st = _T("");
							st = _T("");
							if((rfu_masterq>0) && ((rfu_cmd>=0xa4 && rfu_cmd<=0xa6) || rfu_cmd==0x96 || rfu_cmd==0x9d || rfu_cmd==0x9e ))
							st = DataHex((char*)rfu_masterdata, rfu_masterq<<2); else 
							if(rfu_qrecv>0) st.Format(_T("%08X"), rfu_masterdata[0]);
							log("CMD2 : %08X  %d  %04X %04X  %s\n", READ32LE(&ioMem[COMM_SIODATA32_L]), GetTickCount(), rfu_id, gbaid, (LPCTSTR)st);
							st = _T("");
						}
					#endif
							/*static CString st = _T("");
							if(rfu_masterq==1 && rfu_cmd==0xa4) {
							st = DataHex((char*)rfu_masterdata, rfu_masterq<<2);
							log("CMD3 : %08X %08X %08X %d  %s\n", READ32LE(&ioMem[COMM_SIODATA32_L]), rfu_id, gbaid, GetTickCount(), (LPCTSTR)st);
							}
							st = _T("");*/

				} else { //unknown command word

					UPDATE_REG(COMM_SIODATA32_L, 0);
					UPDATE_REG(COMM_SIODATA32_H, 0x8000);
				}
				break;

			case RFU_SEND:
				if(--rfu_qsend == 0) {
					rfu_state = RFU_COMM;
				}

				switch (rfu_cmd) {
				case 0x16: //broadcast room data
					rfu_masterdata[rfu_counter++] = READ32LE(&ioMem[COMM_SIODATA32_L]);
					break;

				case 0x17: //set game id?
					rfu_masterdata[rfu_counter++] = READ32LE(&ioMem[COMM_SIODATA32_L]);
					break;

				case 0x1f: //Set a room id to join? //join a room
					rfu_masterdata[0] = READ32LE(&ioMem[COMM_SIODATA32_L]);
					//log("CMDx1F : %08X %08X %08X %d \n", rfu_id, gbaid, rfu_masterdata[0], GetTickCount());
					#ifdef GBA_LOGGING
						if(systemVerbose & VERBOSE_LINK) {
							log("CMDx1F : %08X %08X %08X %d \n", rfu_id, gbaid, rfu_masterdata[0], GetTickCount());
						}
					#endif
					break;

				case 0x24: //send data
				case 0x25: //send & wait
					rfu_masterdata[rfu_counter++] = READ32LE(&ioMem[COMM_SIODATA32_L]);
					//if(rfu_cmd==0x24 && rfu_masterdata[0]==1) rfu_masterdata[0]++; //just to see the behaviour
					break;

				case 0x30: //close connection error code?
					rfu_masterdata[0] = READ32LE(&ioMem[COMM_SIODATA32_L]);
					//FIXED-TODO: to check why gbaid sometimes mismatched while rfu_id is still correct here?
					#ifdef GBA_LOGGING
						if(systemVerbose & VERBOSE_LINK) {
							log("CMDx%02X : %08X %08X %08X %d \n", rfu_cmd, rfu_id, gbaid, rfu_masterdata[0], GetTickCount());
						}
					#endif
					break;

				case 0xee: //resend last command?
					rfu_masterdata[0] = READ32LE(&ioMem[COMM_SIODATA32_L]);
					//FIXED-TODO: to check why gbaid sometimes mismatched while rfu_id is still correct here?
					#ifdef GBA_LOGGING
						if(systemVerbose & VERBOSE_LINK) {
							log("CMDx%02X : %08X %08X %08X %d \n", rfu_cmd, rfu_id, gbaid, rfu_masterdata[0], GetTickCount());
						}
					#endif
					break;

				default:
					if(rfu_qsend>0) {
						rfu_masterdata[rfu_counter++] = READ32LE(&ioMem[COMM_SIODATA32_L]);
						//log("CMDx%02X : %08X %08X %02X %08X %d \n", rfu_cmd, rfu_id, gbaid, rfu_qsend, rfu_masterdata[rfu_counter-1], GetTickCount());
					}
				}
				UPDATE_REG(COMM_SIODATA32_L, 0);
				UPDATE_REG(COMM_SIODATA32_H, 0x8000);
				break;

			case RFU_RECV:
				if (--rfu_qrecv == 0) {
					rfu_state = RFU_COMM;
				}

				switch (rfu_cmd) {
				case 0x9d:
				case 0x9e:
					UPDATE_REG(COMM_SIODATA32_L, rfu_masterdata[rfu_counter]&0xffff);
					UPDATE_REG(COMM_SIODATA32_H, rfu_masterdata[rfu_counter++]>>16);
					break;

				case 0xa6:
					UPDATE_REG(COMM_SIODATA32_L, rfu_masterdata[rfu_counter]&0xffff);
					UPDATE_REG(COMM_SIODATA32_H, rfu_masterdata[rfu_counter++]>>16);
					break;

				case 0x90:
				case 0xbd:
					UPDATE_REG(COMM_SIODATA32_L, rfu_masterdata[0]/*(vbaid<<3)+0x61f1*/); //this adapter id?
					UPDATE_REG(COMM_SIODATA32_H, 0x0000);
					break;

				case 0x94:
					//UPDATE_REG(COMM_SIODATA32_L, 0x00ff/*rfu_id*/); //current active connected adapter ID?
					//UPDATE_REG(COMM_SIODATA32_H, 0x0000);
					//break;

				case 0x93:	// it seems like the game doesn't care about this value //vendor id? or this adapter id?
					/*u16 signstr;
					s32 lat;
					lat = (s32)rfu_masterdata[0];
					if(rfu_id==0 || lat<0) signstr = 0; else // no-signal/drop the connection
					if(lat<50) signstr = 0x00ff; else // 0xff=4/4bars
					if(lat<100) signstr = 0x007f; else // 0x7f=3/4bars
					if(lat<200) signstr = 0x003f; else // 0x3f=2/4bars
					if(lat<400) signstr = 0x001f; else // 0x1f=2/4bars
					if(lat<800) signstr = 0x000f; else signstr = 0x0007; // 1-0xf=1/4bars*/
					//signstr = 0xff; //last signal/error code?
					UPDATE_REG(COMM_SIODATA32_L, rfu_masterdata[0]/*signstr*//*(vbaid<<3)+0x61f1*/);	//0x1234 // put anything in here
					UPDATE_REG(COMM_SIODATA32_H, 0x0000);	//0x0200 // also here, but it should be 0200, a flag?
					break;

				case 0x91:
					/*lat = (s32)rfu_masterdata[0];
					if(rfu_id==0 || lat<0) signstr = 0; else // no-signal/drop the connection
					if(lat<50) signstr = 0x00ff; else // 0xff=4/4bars
					if(lat<100) signstr = 0x007f; else // 0x7f=3/4bars
					if(lat<200) signstr = 0x003f; else // 0x3f=2/4bars
					if(lat<400) signstr = 0x001f; else // 0x1f=2/4bars
					if(lat<800) signstr = 0x000f; else signstr = 0x0007; // 1-0xf=1/4bars*/
					UPDATE_REG(COMM_SIODATA32_L, rfu_masterdata[0]/*signstr*/); //signal strength, more than 0xff seems to be invalid signal, latency can be used to simulate signal strength
					UPDATE_REG(COMM_SIODATA32_H, 0x0000);
					break;

				case 0xa0:
				case 0xa1:
					UPDATE_REG(COMM_SIODATA32_L, rfu_masterdata[0]/*(vbaid<<3)+0x61f1*//*0x641b*/); //this adapter id?
					UPDATE_REG(COMM_SIODATA32_H, 0x0000);
					break;

				case 0x9a:
					UPDATE_REG(COMM_SIODATA32_L, rfu_masterdata[rfu_counter]&0xffff);
					UPDATE_REG(COMM_SIODATA32_H, rfu_masterdata[rfu_counter++]>>16);
					break;

				default:
					UPDATE_REG(COMM_SIODATA32_L, 0xffff); //0x0173 //0x0001 //not 0x0000 as default? 
					UPDATE_REG(COMM_SIODATA32_H, 0xffff); //0 //0x8000
					//UPDATE_REG(COMM_SIODATA32_L, 0x0028/*0*//*0xdead*//*0x0173*/); //0x0001 //not 0x0000 as default? 
					//UPDATE_REG(COMM_SIODATA32_H, 0x9966/*0x8000*//*0xbeeb*/); //0x8000
					//rfu_polarity = 1;
					break;
				}
				break;
			}
			transfer = 1;
		}

		//if(transfer) //&& rfu_state!=RFU_INIT
			if (value & 8) //Transfer Enable Flag Send (bit.3, 1=Disable Transfer/Not Ready)
				value &= 0xfffb; //Transfer enable flag receive (0=Enable Transfer/Ready, bit.2=bit.3 of otherside)	// A kind of acknowledge procedure
			else //(Bit.3, 0=Enable Transfer/Ready)
				value |= 4; //bit.2=1 (otherside is Not Ready)

		if (rfu_polarity)
			value ^= 4;	// sometimes it's the other way around

	default: //other SIO modes
		return value;
	}
}

// The GBA wireless RFU (see adapter3.txt)
// Just try to avert your eyes for now ^^ (note, it currently can be called, tho)
u16 StartRFU(u16 value)
{
	static CString st = _T("");

	static bool logstartd;
	u32 CurCOM = 0, CurDAT = 0;
	bool rfulogd = (READ16LE(&ioMem[COMM_SIOCNT])!=value);

	switch (GetSIOMode(value, READ16LE(&ioMem[COMM_RCNT]))) {
	case NORMAL8:
		rfu_polarity = 0;
		return value;
		break;

	case NORMAL32:
		if (transfer) return value; //don't do anything if previous cmd aren't sent yet, may fix Boktai2 Not Detecting wireless adapter

		#ifdef GBA_LOGGING
			if(systemVerbose & VERBOSE_LINK) {
				if(!logstartd)
				if(rfulogd) {
					//log("%08X : %04X  ", GetTickCount(), value);
					st.Format(_T("%08X : %04X"), GetTickCount(), value);
				}
			}
		#endif

		//Moving this to the bottom might prevent Mario Golf Adv from Occasionally Not Detecting wireless adapter
		if (value & 8) //Transfer Enable Flag Send (SO.bit.3, 1=Disable Transfer/Not Ready)
			value &= 0xfffb; //Transfer enable flag receive (0=Enable Transfer/Ready, SI.bit.2=SO.bit.3 of otherside)	// A kind of acknowledge procedure
		else //(SO.Bit.3, 0=Enable Transfer/Ready)
			value |= 4; //SI.bit.2=1 (otherside is Not Ready)

		if ((value & 5) == 1)
			value |= 0x02; //wireless always use 2Mhz speed right? this will fix MarioGolfAdv Not Detecting wireless

		if (value & 0x80) //start/busy bit
		{
			//value |= 0x02; //wireless always use 2Mhz speed right? this will fix MarioGolfAdv Not Detecting wireless

			if ((value & 3) == 1) //internal clock w/ 256KHz speed
				rfu_transfer_end = 2048;
			else //external clock or any clock w/ 2MHz speed
				rfu_transfer_end = 256;

			u16 a = READ16LE(&ioMem[COMM_SIODATA32_H]);

			#ifdef GBA_LOGGING
				if(systemVerbose & VERBOSE_LINK) {
					if(rfulogd)
						st.Format(_T("%s    %08X"), (LPCTSTR)st, READ32LE(&ioMem[COMM_SIODATA32_L])); else
					st.Format(_T("%08X : %04X    %08X"), GetTickCount(), value, READ32LE(&ioMem[COMM_SIODATA32_L]));
					logstartd = true;
				}
			#endif

			switch (rfu_state) {
			case RFU_INIT:
				if (READ32LE(&ioMem[COMM_SIODATA32_L]) == 0xb0bb8001) {
					rfu_state = RFU_COMM;	// end of startup
					rfu_initialized = true;
					//rfu_polarity = 0;
				}

				UPDATE_REG(COMM_SIODATA32_H, READ16LE(&ioMem[COMM_SIODATA32_L]));
				UPDATE_REG(COMM_SIODATA32_L, a);
				break;

			case RFU_COMM:
				CurCOM = READ32LE(&ioMem[COMM_SIODATA32_L]);
				if (a == 0x9966) //initialize cmd
				{
					u8 tmpcmd = CurCOM;
					if(tmpcmd!=0x10 && tmpcmd!=0x11 && tmpcmd!=0x13 && tmpcmd!=0x14 && tmpcmd!=0x16 && tmpcmd!=0x17 && tmpcmd!=0x19 && tmpcmd!=0x1a && tmpcmd!=0x1b && tmpcmd!=0x1c && tmpcmd!=0x1d && tmpcmd!=0x1e && tmpcmd!=0x1f && tmpcmd!=0x20 && tmpcmd!=0x21 && tmpcmd!=0x24 && tmpcmd!=0x25 && tmpcmd!=0x26 && tmpcmd!=0x27 && tmpcmd!=0x30 && tmpcmd!=0x3d && tmpcmd!=0xa8 && tmpcmd!=0xee)
						log("%08X : UnkCMD %02X  %04X  %08X %08X\n", GetTickCount(), tmpcmd, PrevVAL, PrevCOM, PrevDAT);

					if ((rfu_qsend2=rfu_qsend=ioMem[0x121]) != 0) { //COMM_SIODATA32_L+1, following data [to send]
						rfu_state = RFU_SEND;
						rfu_counter = 0;
					}

					if(ioMem[COMM_SIODATA32_L] == 0xee) { //0xee cmd shouldn't override previous cmd
						rfu_lastcmd = rfu_cmd2;
						rfu_cmd2 = ioMem[COMM_SIODATA32_L];
						//rfu_polarity = 0; //when polarity back to normal the game can initiate a new cmd even when 0xee hasn't been finalized, but it looks improper isn't?
					} else {
					rfu_lastcmd = rfu_cmd;
					rfu_cmd = ioMem[COMM_SIODATA32_L];
					rfu_cmd2 = 0;
					
					if (rfu_cmd==0x27 || rfu_cmd==0x37) {
						rfu_lastcmd2 = rfu_cmd;
						rfu_lasttime = GetTickCount();
					} else
					if (rfu_cmd == 0x24) { //non-important data shouldn't overwrite important data from 0x25
						rfu_lastcmd2 = rfu_cmd;
						rfu_cansend = false;
						rfu_lasttime = GetTickCount();
						while (linkmem->numgbas>=2 && linkmem->rfu_q[vbaid]>1 && linkmem->rfu_signal[vbaid] && linkmem->rfu_signal[1-vbaid] && (GetTickCount()-rfu_lasttime)<(DWORD)linktimeout) { //2 players
							SetEvent(linksync[1-vbaid]); //unlock other gba, allow other gba to move (sending their data)  //is max value of vbaid=1 ?
							WaitForSingleObject(linksync[vbaid], 1); //linktimeout //wait until this gba allowed to move (to prevent both GBAs from using 0x25 at the same time)
							ResetEvent(linksync[vbaid]); //lock this gba, don't allow this gba to move (prevent sending another data too fast w/o giving the other side chances to read it)
						}
						//SetEvent(linksync[vbaid]); //set again to reduce the lag since it will be waited again during finalization cmd

						/*if(linkmem->numgbas>=2 && linkmem->rfu_signal[vbaid] && linkmem->rfu_signal[1-vbaid] && linkmem->rfu_q[vbaid]>1) { //2 players
							SetEvent(linksync[1-vbaid]); //needed to balance performance on all GBAs? //unlock other gba, allow other gba to move (sending their data)  //is max value of vbaid=1 ?
							WaitForSingleObject(linksync[vbaid], linktimeout); //1 //wait until this gba allowed to move
							ResetEvent(linksync[vbaid]); //lock this gba, don't allow this gba to move (prevent sending another data too fast w/o giving the other side chances to read it)
						}*/
						if(/*!linkmem->rfu_proto[vbaid] ||*/ linkmem->rfu_q[vbaid]<2) {
							rfu_cansend = true;
							linkmem->rfu_q[vbaid] = 0; //rfu_qsend;
							//linkmem->rfu_proto[vbaid] = 0;
						} else rfu_waiting = true; //don't wait with speedhack
					} else
					if (rfu_cmd == 0x25 || rfu_cmd == 0x35) {
						rfu_lastcmd2 = rfu_cmd;
						rfu_cansend = false;
						//previous important data need to be received successfully before sending another important data
						rfu_lasttime = GetTickCount();
						while (linkmem->numgbas>=2 && linkmem->rfu_q[vbaid]>1 /*&& linkmem->rfu_proto[vbaid]*/ && linkmem->rfu_signal[vbaid] && linkmem->rfu_signal[1-vbaid] && (GetTickCount()-rfu_lasttime)<(DWORD)linktimeout) { //2 players
							SetEvent(linksync[1-vbaid]); //unlock other gba, allow other gba to move (sending their data)  //is max value of vbaid=1 ?
							WaitForSingleObject(linksync[vbaid], 1); //linktimeout //wait until this gba allowed to move (to prevent both GBAs from using 0x25 at the same time)
							ResetEvent(linksync[vbaid]); //lock this gba, don't allow this gba to move (prevent sending another data too fast w/o giving the other side chances to read it)
						}
						//SetEvent(linksync[vbaid]); //set again to reduce the lag since it will be waited again during finalization cmd
						if(linkmem->numgbas>=2 && linkmem->rfu_q[vbaid]>1 /*&& linkmem->rfu_proto[vbaid]*/ && linkmem->rfu_signal[vbaid] && linkmem->rfu_signal[1-vbaid]) rfu_waiting = true; else //don't wait with speedhack
						{
							rfu_cansend = true;
							linkmem->rfu_q[vbaid] = 0; //rfu_qsend;
							//linkmem->rfu_proto[vbaid] = 1;
						}
					}
					/*if(rfu_cmd == 0xa8 || rfu_cmd == 0xb6) { 
						rfu_polarity = 0; //not necessary, may cause the game to resend 0x8000 since the game will reverse the polarity after sending 0xa8 command
						//rfu_state = RFU_COMM;
					}*/
					}
					if(!rfu_waiting) {
						UPDATE_REG(COMM_SIODATA32_L, 0);
						UPDATE_REG(COMM_SIODATA32_H, 0x8000);
					}
				}
				else if (a == 0x8000) //finalize cmd, the game will send this when polarity reversed (expecting something)
				{
					rfu_qrecv = 0;
					rfu_counter = 0;
					if(rfu_cmd2 == 0xee) {
						if(rfu_masterdata[0] == 2)
						rfu_polarity = 0; //to normalize polarity after finalize looks more proper
						UPDATE_REG(COMM_SIODATA32_H, 0x9966);
						UPDATE_REG(COMM_SIODATA32_L, (rfu_qrecv<<8) | (rfu_cmd2^0x80));
					} else {
					switch (rfu_cmd) {
					case 0x1a:	// check if someone joined
						if (linkmem->rfu_request[vbaid] != 0) {
							rfu_state = RFU_RECV;
							rfu_qrecv = 1;
							//linkmem->rfu_signal[vbaid] = 0xff;
						}
						linkid = -1; //is this gba id?
						rfu_cmd ^= 0x80;
						break;

					case 0x1f:	// pick/join a server
						linkmem->rfu_request[vbaid] = 0;
						linkmem->rfu_q[vbaid] = 0;
						linkmem->rfu_signal[vbaid] = 0xff;
						linkmem->rfu_signal[1-vbaid] = 0xff;
						rfu_cmd ^= 0x80;
						break;

					case 0x1e:	// receive broadcast data
					case 0x1d:	// no visible difference
						if(linkmem->rfu_bdata[1-vbaid][0])
						memcpy(rfu_masterdata, linkmem->rfu_bdata[1-vbaid], sizeof(linkmem->rfu_bdata[1-vbaid])); else
						memset(rfu_masterdata, 0, sizeof(linkmem->rfu_bdata[1-vbaid]));
						rfu_polarity = 0;
						rfu_state = RFU_RECV;
						rfu_qrecv = 7;
						rfu_counter = 0;
						rfu_cmd ^= 0x80;
						break;

					case 0x11:	// ? always receives 0xff - I suspect it's something for 3+ players
						if(linkmem->numgbas>=2 && (linkmem->rfu_request[vbaid]|linkmem->rfu_request[1-vbaid]))
						linkmem->rfu_signal[vbaid] = 0x00ff; else linkmem->rfu_signal[vbaid] = 0;
						rfu_cmd ^= 0x80;
						rfu_polarity = 0;
						rfu_state = RFU_RECV; //3;
						rfu_qrecv = 1;
						break;

					case 0x13:	// unknown
					case 0x14:	// unknown
					case 0x20:	// this has something to do with 0x1f
					case 0x21:	// this too
						rfu_cmd ^= 0x80;
						rfu_polarity = 0;
						rfu_state = RFU_RECV; //3;
						rfu_qrecv = 1;
						break;

					case 0x19:	// server bind/start listening for client to join
						rfu_ishost = true;
						rfu_id = 0x61f1;
						//linkmem->rfu_q[vbaid] = 0;
						linkmem->rfu_bdata[vbaid][0] = 0x61f1; //(vbaid*8)+0x61f1 //host always have an id of 0x61f1?
						//linkmem->rfu_signal[vbaid] = 0xff;
						rfu_cmd ^= 0x80;
						rfu_polarity = 0;
						//ResetEvent(linksync[vbaid]); //lets client to send 1st (this will help reducing the chance for both side using 0x25 at the same time) //may not works as intended when both GBAs called SetEvent at the same time, need to use WaitFor before calling SetEvent in order to works
						break;

					case 0x36:
					case 0x26:
						if((rfu_qrecv=rfu_masterq=linkmem->rfu_q[1-vbaid])!=0){ //is max value of vbaid=1 ?
							rfu_state = RFU_RECV;
							rfu_counter = 0;
							//SetEvent(linksync[1-vbaid]); //unlock other gba, allow other gba to move (sending their data) //faster but may affect stability and cause both GBAs using 0x25 at the same time, too fast communication could also cause the game from updating the screen
							//WaitForSingleObject(linksync[vbaid], linktimeout);
							memcpy(rfu_masterdata, linkmem->rfu_data[1-vbaid], min(rfu_masterq<<2,sizeof(rfu_masterdata))); //128 //read data from other GBA
							linkmem->rfu_qid[1-vbaid] = 0;
							linkmem->rfu_q[1-vbaid] = 0; //mark that it has been received successfully
							//ResetEvent(linksync[vbaid]); //linksync[vbaid] //lock this gba, don't allow this gba to move (prevent both GBA using 0x25 at the same time) //slower but improve stability by preventing both GBAs from using 0x25 at the same time
							rfu_lastcmd2 = 0;
						}
						rfu_cmd ^= 0x80;
						break;

					case 0x24:	// send [non-important] data (used by server often)
						if(rfu_cansend) {
							linkmem->rfu_proto[vbaid] = 0;
							linkmem->rfu_q[vbaid] = rfu_qsend2;
						} else {
							//#ifdef GBA_LOGGING
							//	if(systemVerbose & VERBOSE_LINK) {
									log("%08X : IgnoredSend[%02X] %d\n", GetTickCount(), rfu_cmd, rfu_qsend2);
							//	}
							//#endif
						}
						if((numtransfers++)==0) 
							linktime = 1; //numtransfers used to reset linktime to prevent it from reaching beyond max value of integer? //numtransfers doesn't seems to be used?
						linkmem->rfu_linktime[vbaid] = linktime; //save the ticks before reseted to zero
						rfu_cmd ^= 0x80;
						linktime = 0; //need to zeroed when sending? //0 might cause slowdown in performance
						//linkid = -1; //not needed?
						break;

					case 0x35:
					case 0x25:	// send [important] data & wait for [important?] reply data
						if(rfu_cansend) {
							linkmem->rfu_proto[vbaid] = 1;
							linkmem->rfu_q[vbaid] = rfu_qsend2;
						} else {
							//#ifdef GBA_LOGGING
							//	if(systemVerbose & VERBOSE_LINK) {
									log("%08X : IgnoredSend[%02X] %d\n", GetTickCount(), rfu_cmd, rfu_qsend2);
							//	}
							//#endif
						}
						//TODO: there is still a chance for 0x25 to be used at the same time on both GBA (when both side called SetEvent(linksync[1-vbaid]) nearly at the same time for the 1st time)
						//Waiting here for previous data to be received might be too late! as new data already sent before finalization cmd
						rfu_cmd ^= 0x80;
						break;

					case 0x16:	// send broadcast data (ie. room name)
						//linkmem->rfu_bdata[vbaid][0] = 0x61f1; //(vbaid*8)+0x61f1 //host always have an id of 0x61f1?
						rfu_cmd ^= 0x80;
						linkmem->rfu_q[vbaid] = 0;
						break;

					case 0x17:	// setup or something ?
					case 0x33:	//
					case 0x27:	// wait for data ?
					case 0x37:	// wait for data ?
					default:
						rfu_cmd ^= 0x80;
						break;

					case 0x1b:	//might reset some data?
						linkmem->rfu_bdata[vbaid][0] = 0; //0 may cause player unable to join in pokemon union room
						//memset(linkmem->rfu_bdata[vbaid], 0, sizeof(linkmem->rfu_bdata[vbaid]));
						rfu_cmd ^= 0x80;
						break;

					case 0x1c:
						rfu_ishost = false;
						rfu_id = 0x61f9;
						linkmem->rfu_q[vbaid] = 0;
						rfu_cmd ^= 0x80;
						break;

					case 0x30: //reset some data
						if (linkmem->numgbas >= 2) {
							linkmem->rfu_request[1-vbaid] = 0;
							linkmem->rfu_signal[1-vbaid] = 0;
							SetEvent(linksync[1-vbaid]); //allow other gba to move //is max value of vbaid=1 ?
						} 
						WaitForSingleObject(linksync[vbaid], linktimeout);
						while (linkmem->rfu_signal[vbaid]!=0) {
						linkmem->rfu_request[vbaid] = 0; //There is a possibility where rfu_request didn't get zeroed here when it's being read by the other GBA at the same time
						linkmem->rfu_signal[vbaid] = 0;
						SleepEx(1,true);
						}
						//linkmem->rfu_q[vbaid] = 0;
						linkmem->rfu_proto[vbaid] = 0;
						linkmem->rfu_reqid[vbaid] = 0;
						linkmem->rfu_linktime[vbaid] = 0;
						linkmem->rfu_gdata[vbaid] = 0;
						linkmem->rfu_bdata[vbaid][0] = 0;
						//memset(linkmem->rfu_bdata[vbaid], 0, sizeof(linkmem->rfu_bdata[vbaid]));
						rfu_polarity = 0; //is this included?
						linkid = -1; //0;
						numtransfers = 0;
						rfu_cmd |= 0x80;
						SetEvent(linksync[vbaid]); //may not be needed
						break;

					case 0x3d:	// init/reset rfu data
						rfu_initialized = false;
					case 0x10:	// init/reset rfu data
						if (linkmem->numgbas >= 2) {
							linkmem->rfu_request[1-vbaid] = 0;
							linkmem->rfu_signal[1-vbaid] = 0;
							SetEvent(linksync[1-vbaid]); //allow other gba to move //is max value of vbaid=1 ?
						} 
						WaitForSingleObject(linksync[vbaid], linktimeout);
						while (linkmem->rfu_signal[vbaid]!=0) {
						linkmem->rfu_request[vbaid] = 0; //There is a possibility where rfu_request didn't get zeroed here when it's being read by the other GBA at the same time
						linkmem->rfu_signal[vbaid] = 0;
						SleepEx(1,true);
						}
						//linkmem->rfu_q[vbaid] = 0;
						linkmem->rfu_proto[vbaid] = 0;
						linkmem->rfu_reqid[vbaid] = 0;
						linkmem->rfu_linktime[vbaid] = 0;
						linkmem->rfu_gdata[vbaid] = 0;
						linkmem->rfu_bdata[vbaid][0] = 0;
						//memset(linkmem->rfu_bdata[vbaid], 0, sizeof(linkmem->rfu_bdata[vbaid]));
						rfu_polarity = 0; //is this included?
						linkid = -1; //0;
						numtransfers = 0;
						SetEvent(linksync[vbaid]); //may not be needed
						rfu_cmd |= 0x80;
						break;

					case 0xb5:	//	2nd part of send&wait function 0x25
					case 0xb7:	//	2nd part of wait function 0x27
					case 0xa5:	//	2nd part of send&wait function 0x25
					case 0xa7:	//	2nd part of wait function 0x27
						//rfu_polarity = 1; //reverse polarity to make the game send 0x80000000 command word (to be replied with 0x99660028 later by the adapter)
						rfu_waiting = true;
						//rfu_cmd = 0x28;

						/*if (linkid == -1) { //needed? //related to 0x24? or for initialization when RFU started?
							linkid++;
							linkmem->rfu_linktime[vbaid] = 0;
						}*/
						/*if (linkmem->rfu_signal[1-vbaid]==0) { //linkid && linkmem->rfu_request[1-vbaid]==0 //if GBA not joined //is max value of vbaid=1 ?
							linkmem->rfu_q[1-vbaid] = 0; //data size = 0 -> not sending //is max value of vbaid=1 ?
							rfu_transfer_end = 256;
							linktime = 0;
							//rfu_polarity = 1;
							//rfu_cmd = 0x28; //0x29; //is this command (0x29) existed?
							break;
						}*/
						
						if ((numtransfers++) == 0) //numtransfers used to reset linktime to prevent it from reaching beyond max value of integer? //seems to be needed? otherwise data can't be received properly? //related to 0x24?
							linktime = 1; //0;
						linkmem->rfu_linktime[vbaid] = linktime; //save the ticks before changed to synchronize performance
						//prevent GBAs from sending data at the same time (which may cause waiting at the same time in the case of 0x25), also gives time for the other side to read the data
						if (linkmem->numgbas>=2 && linkmem->rfu_signal[vbaid]) {
							//if (!linkid || (linkid && numtransfers)) //not needed?
								//SetEvent(linksync[1-vbaid]); //allow other gba to move (sending their data)
							//WaitForSingleObject(linksync[vbaid], 1/*linktimeout*/); //wait until this gba allowed to move
							//ResetEvent(linksync[vbaid]); //don't allow this gba to move (prevent sending another data too fast w/o giving the other side chances to read it)
						}
						
						rfu_transfer_end = linkmem->rfu_linktime[1-vbaid] - linktime + 256; //waiting ticks = ticks difference between GBAs send/recv? //is max value of vbaid=1 ?
						
						if (rfu_transfer_end < 256)
							rfu_transfer_end = 256;

						linktime = -rfu_transfer_end; //needed to synchronize performance on both side

						//rfu_polarity = 1;
						//rfu_cmd = 0x28;
						break;
					}
					if(!rfu_waiting) {
						UPDATE_REG(COMM_SIODATA32_H, 0x9966);
						UPDATE_REG(COMM_SIODATA32_L, (rfu_qrecv<<8) | rfu_cmd);
					}
					}
				} else { //unknown COMM word
					log("%08X : UnkCOM %08X  %04X  %08X %08X\n", GetTickCount(), READ32LE(&ioMem[COMM_SIODATA32_L]), PrevVAL, PrevCOM, PrevDAT);
					rfu_cmd ^= 0x80;
					UPDATE_REG(COMM_SIODATA32_L, 0);
					UPDATE_REG(COMM_SIODATA32_H, 0x8000);
				}
				break;

			case RFU_SEND: //data following after initialize cmd
				CurDAT = READ32LE(&ioMem[COMM_SIODATA32_L]);
				if(--rfu_qsend == 0) {
					rfu_state = RFU_COMM;
				}

				switch (rfu_cmd) {
				case 0x16:
					linkmem->rfu_bdata[vbaid][1 + rfu_counter++] = READ32LE(&ioMem[COMM_SIODATA32_L]);
					break;

				case 0x17:
					linkid = 1;
					rfu_masterdata[rfu_counter++] = READ32LE(&ioMem[COMM_SIODATA32_L]);
					break;

				case 0x1f:
					rfu_masterdata[rfu_counter++] = READ32LE(&ioMem[COMM_SIODATA32_L]);
					linkmem->rfu_request[1-vbaid] = 2; //1 // tells the other GBA(a host) that someone(a client) is joining //is max value of vbaid=1 ?
					break;

				case 0x24:
					//if(linkmem->rfu_proto[vbaid]) break; //important data from 0x25 shouldn't be overwritten by 0x24
				case 0x25:
					if(rfu_cansend)
					linkmem->rfu_data[vbaid][rfu_counter++] = READ32LE(&ioMem[COMM_SIODATA32_L]);
					break;

				default:
					rfu_masterdata[rfu_counter++] = READ32LE(&ioMem[COMM_SIODATA32_L]);
					break;
				}
				UPDATE_REG(COMM_SIODATA32_L, 0);
				UPDATE_REG(COMM_SIODATA32_H, 0x8000);
				break;

			case RFU_RECV: //data following after finalize cmd
				if (--rfu_qrecv == 0)
					rfu_state = RFU_COMM;

				switch (rfu_cmd) {
				case 0x9d:
				case 0x9e:
					UPDATE_REG(COMM_SIODATA32_L, rfu_masterdata[rfu_counter]&0xffff);
					UPDATE_REG(COMM_SIODATA32_H, rfu_masterdata[rfu_counter++]>>16);
					break;

				case 0xa6:
					UPDATE_REG(COMM_SIODATA32_L, rfu_masterdata[rfu_counter]&0xffff);
					UPDATE_REG(COMM_SIODATA32_H, rfu_masterdata[rfu_counter++]>>16);
					break;

				case 0x94:	//last error code? //it seems like the game doesn't care about this value
					if(/*linkmem->rfu_signal[vbaid]*/rfu_initialized) {
						UPDATE_REG(COMM_SIODATA32_L, 0x61f9); //((1-vbaid)<<3)+0x61f1
						UPDATE_REG(COMM_SIODATA32_H, 0x0000);
						//UPDATE_REG(COMM_SIODATA32_L, 0x1234);	// put anything in here
						//UPDATE_REG(COMM_SIODATA32_H, 0x0200);	// also here, but it should be 0200
					} else {
						UPDATE_REG(COMM_SIODATA32_L, 0);	// put anything in here
						UPDATE_REG(COMM_SIODATA32_H, 0x0000);
					}
					break;
				case 0x93:	//last error code? //it seems like the game doesn't care about this value
					if(/*linkmem->rfu_signal[vbaid]*/rfu_initialized) {
						UPDATE_REG(COMM_SIODATA32_L, rfu_id); //(vbaid<<3)+0x61f1
						//UPDATE_REG(COMM_SIODATA32_H, 0x0000);
						//UPDATE_REG(COMM_SIODATA32_L, 0x1234);	// put anything in here
						UPDATE_REG(COMM_SIODATA32_H, /*0x0200*/rfu_id?0x0200:0);	// also here, but it should be 0200 //need to be 0100 (or higher) to maintain stability in MarioGolfAdv
					} else {
						UPDATE_REG(COMM_SIODATA32_L, 0);	// put anything in here
						UPDATE_REG(COMM_SIODATA32_H, 0x0000);
					}
					break;

				case 0xa0:
				case 0xa1:
					//UPDATE_REG(COMM_SIODATA32_L, 0x641b); //max id value?
					UPDATE_REG(COMM_SIODATA32_L, 0x61f9); //((1-vbaid)<<3)+0x61f1
					UPDATE_REG(COMM_SIODATA32_H, 0x0000);
					break;

				case 0x9a:
					UPDATE_REG(COMM_SIODATA32_L, 0x61f9); //(vbaid*8)+0x61f1 //client always have an id of 0x61f9?
					UPDATE_REG(COMM_SIODATA32_H, 0);
					break;

				case 0x91: //signal strength
					UPDATE_REG(COMM_SIODATA32_L, linkmem->rfu_signal[vbaid]&0xffff); //
					UPDATE_REG(COMM_SIODATA32_H, linkmem->rfu_signal[vbaid]>>16);
					break;

				default: //unknown data (should use 0 or -1 as default), usually returning 0 might cause the game to think there is something wrong with the connection (ie. 0x11/0x13 cmd)
					UPDATE_REG(COMM_SIODATA32_L, 0xffff);  //0x0173 //not 0x0000 as default?
					UPDATE_REG(COMM_SIODATA32_H, 0xffff); //0x0000
					break;
				}
			break;
			}
			transfer = 1;

			PrevVAL = value;
			PrevDAT = CurDAT;
			PrevCOM = CurCOM;

			#ifdef GBA_LOGGING
				if(systemVerbose & VERBOSE_LINK) {
					if(logstartd)
					if(rfu_state == RFU_COMM)
					st.Format(_T("%s   %08X   [%d, %d, %d]"), (LPCTSTR)st, READ32LE(&ioMem[COMM_SIODATA32_L]), numtransfers, linktime, linkmem->rfu_linktime[vbaid]); else //sometimes getting exception due to "Too small buffer" when st="";
					st.Format(_T("%s   %08X"), (LPCTSTR)st, READ32LE(&ioMem[COMM_SIODATA32_L])); //
					logstartd = false;
				}
			#endif
		}

		//if(transfer) //&& rfu_state!=RFU_INIT
			//Moved from the top to fix Mario Golf Adv from Occasionally Not Detecting wireless adapter
			/*if (value & 8) //Transfer Enable Flag Send (bit.3, 1=Disable Transfer/Not Ready)
				value &= 0xfffb; //Transfer enable flag receive (0=Enable Transfer/Ready, bit.2=bit.3 of otherside)	// A kind of acknowledge procedure
			else //(Bit.3, 0=Enable Transfer/Ready)
				value |= 4; //bit.2=1 (otherside is Not Ready)*/

		if (rfu_polarity)
			value ^= 4;	// sometimes it's the other way around

		#ifdef GBA_LOGGING
				if(systemVerbose & VERBOSE_LINK) {
					if(st != _T(""))
					log("%s\n", (LPCTSTR)st);
					logstartd = false;
					st = _T("");
				}
		#endif

	default: //other SIO modes
		return value;
	}
}

//////////////////////////////////////////////////////////////////////////
// Probably from here down needs to be replaced with SFML goodness :)

void LinkConnected(bool b) {
	c_s.Lock();
	if(!linkid) { //0 = server
		//lanlink.connected = false;
		for(int i=1; i<=lanlink.numgbas; i++)
		ls.connected[i] = b; //lanlink.connected |= ls.connected[i];
	} //else 
	lanlink.connected = b;
	c_s.Unlock();
}

bool IsLinkConnected() {
	c_s.Lock();
	if(!linkid) { //0 = server
		lanlink.connected = false;
		for(int i=1; i<=lanlink.numgbas; i++)
		lanlink.connected |= ls.connected[i];
	};
	bool b = lanlink.connected;
	c_s.Unlock();
	return b;
}

int InitLink()
{
	WSADATA wsadata;
	BOOL disable = true;
	DWORD timeout = 5000; //linktimeout; //used on windows
	//struct timeval tv; //used on linux/bsd
	//tv.tv_sec = timeout / 1000;
	//tv.tv_usec = timeout % 1000;
	int sz = 65536; //linkbuffersize; //32767; //too small buffer may cause timeout when sending while the buffer is still full, too large may cause noticibly delays
	//int len = sizeof(int);
	unsigned long notblock = 1; //AdamN: 0=blocking, non-zero=non-blocking

	linkid = 0;

	if(WSAStartup(MAKEWORD(1,1), &wsadata)!=0){
		WSACleanup();
		return 0;
	}

	if((lanlink.tcpsocket=socket(AF_INET, SOCK_STREAM, IPPROTO_TCP))==INVALID_SOCKET){
		MessageBox(NULL, _T("Couldn't create socket."), _T("Error!"), MB_OK);
		WSACleanup();
		return 0;
	}

	setsockopt(lanlink.tcpsocket, IPPROTO_TCP, TCP_NODELAY, (char*)&disable, sizeof(BOOL)); //true=send packet immediately

	//setsockopt(lanlink.tcpsocket, SOL_SOCKET, SO_RCVTIMEO, (const char*)timeout/*tv*/, sizeof(timeout/*timeval*/)); //setting recv timeout //might be buggy on Win7++ resulting a zero timeout
	//setsockopt(lanlink.tcpsocket, SOL_SOCKET, SO_SNDTIMEO, (const char*)timeout/*tv*/, sizeof(timeout/*timeval*/)); //setting send timeout //might be buggy on Win7++ resulting a zero timeout
	//getsockopt(lanlink.tcpsocket, SOL_SOCKET, SO_RCVBUF, (char*)&sz, (int*)&len); //setting recv buffer
	setsockopt(lanlink.tcpsocket, SOL_SOCKET, SO_RCVBUF, (char*)&sz, sizeof(int)); //setting recv buffer
	setsockopt(lanlink.tcpsocket, SOL_SOCKET, SO_SNDBUF, (char*)&sz, sizeof(int)); //setting send buffer

	/*if(ioctlsocket(lanlink.tcpsocket, FIONBIO, &notblock)==SOCKET_ERROR) { //AdamN: activate non-blocking mode (by default sockets are using blocking mode after created)
		MessageBox(NULL, _T("Couldn't enable non-blocking socket."), _T("Error!"), MB_OK);
		closesocket(lanlink.tcpsocket);
		WSACleanup();
		return 0;
	}*/

	if((mmf=CreateFileMapping(INVALID_HANDLE_VALUE, NULL, PAGE_READWRITE, 0, sizeof(LINKDATA), _T("VBA link memory")))==NULL){
		closesocket(lanlink.tcpsocket);
		WSACleanup();
		MessageBox(NULL, _T("Error creating file mapping"), _T("Error"), MB_OK|MB_ICONEXCLAMATION);
		return 0;
	}

	if(GetLastError() == ERROR_ALREADY_EXISTS)
		vbaid = 1; //is max value of vbaid=1 ?
	else
		vbaid = 0;

	if((linkmem=(LINKDATA *)MapViewOfFile(mmf, FILE_MAP_WRITE, 0, 0, sizeof(LINKDATA)))==NULL){
		closesocket(lanlink.tcpsocket);
		WSACleanup();
		CloseHandle(mmf);
		MessageBox(NULL, _T("Error mapping file"), _T("Error"), MB_OK|MB_ICONEXCLAMATION);
		return 0;
	}

	if(linkmem->linkflags & LINK_PARENTLOST)
		vbaid = 0;

	if(vbaid==0) {
		linkid = 0;
		if(linkmem->linkflags & LINK_PARENTLOST){
			linkmem->numgbas++;
			linkmem->linkflags &= ~LINK_PARENTLOST;
		}
		else
			linkmem->numgbas=1; //0;

		for(i=0;i<5;i++){ //i<5
			linkevent[15]=(char)i+'1';
			if((linksync[i]=CreateEvent(NULL, true, false, linkevent))==NULL){
				closesocket(lanlink.tcpsocket);
				WSACleanup();
				UnmapViewOfFile(linkmem);
				CloseHandle(mmf);
				//linkmem = NULL;
				for(j=0;j<i;j++){
					CloseHandle(linksync[j]);
				}
				MessageBox(NULL, _T("Error opening event"), _T("Error"), MB_OK|MB_ICONEXCLAMATION);
				return 0;
			} else SetEvent(linksync[i]);
		}
	} else { //vbaid!=0
		vbaid = linkmem->numgbas; //is this safe with the existance of codes using [1-vbaid]? //is max value of vbaid=1 ?
		linkid = vbaid; //is this safe? as InitLink might be called more than once, thus causing vbaid to change on the next calls
		linkmem->numgbas++;

		if(linkmem->numgbas>5){
			linkmem->numgbas=5;
			closesocket(lanlink.tcpsocket);
			WSACleanup();
			MessageBox(NULL, _T("6 or more GBAs are not supported."), _T("Error! Too many GBAs"), MB_OK|MB_ICONEXCLAMATION);
			UnmapViewOfFile(linkmem);
			CloseHandle(mmf);
			//linkmem = NULL;
			return 0;
		}
		for(i=0;i<5;i++){
			linkevent[15]=(char)i+'1';
			if((linksync[i]=OpenEvent(EVENT_ALL_ACCESS, false, linkevent))==NULL){
				closesocket(lanlink.tcpsocket);
				WSACleanup();
				//CloseHandle(mmf);
				UnmapViewOfFile(linkmem);
				CloseHandle(mmf);
				//linkmem = NULL;
				for(j=0;j<i;j++){
					CloseHandle(linksync[j]);
				}
				MessageBox(NULL, _T("Error opening event"), _T("Error"), MB_OK|MB_ICONEXCLAMATION);
				return 0;
			} else SetEvent(linksync[i]);
		}
	}

	//if(linkmem) vbaid = linkmem->numgbas-1; //is this safe with the existance of codes using [1-vbaid]? //is max value of vbaid=1 ?
	//linkid = vbaid; //InitLink might be called more than once, thus causing vbaid to change and causing a bug
	//log("VBAid : %08X %08X %08X %08X %d \n", vbaid, linkid, linkmem->numgbas, lanlink.numgbas, GetTickCount());

	rfu_thisid = (vbaid<<3)+0x61f1; //0x61f1+vbaid; //rfu_thisid might be inaccurate as vbaid here is inaccurate ?
	if(linkmem) {
	linkmem->lastlinktime=0xffffffff;
	linkmem->numtransfers=0;
	linkmem->linkflags=0;
	//lanlink.connected = false;
	//lanlink.thread = NULL;
	//lanlink.speed = false;
	for(i=0;i<4;i++){
		linkmem->linkdata[i] = 0xffff;
		linkdata[i] = 0xffff;
		linkdatarecvd[i] = false;
	}
	}
	LinkConnected(false);
	lanlink.thread = NULL;
	//lanlink.speed = false;
	gbaid = vbaid;
	return 1; //1=sucessful?
}

void CloseLink(void){
	char outbuffer[12];
	if(/*lanlink.active &&*/ IsLinkConnected()/*lanlink.connected*/){
		if(linkid){ //Client
			//char outbuffer[4];
			outbuffer[0] = 4;
			outbuffer[1] = -32;
			if(lanlink.type==0) send(lanlink.tcpsocket, outbuffer, 4, 0);
		} else { //Server
			//char outbuffer[12];
			int i;
			outbuffer[0] = 12; //should be 4 also isn't?
			outbuffer[1] = -32;
			for(i=1;i<=lanlink.numgbas;i++){
				if(lanlink.type==0){
					send(ls.tcpsocket[i], outbuffer, 12, 0);
				}
				closesocket(ls.tcpsocket[i]);
			}
		}
	}
	if(linkmem) {
		linkmem->numgbas--;
		if(!linkid&&linkmem->numgbas!=0)
			linkmem->linkflags|=LINK_PARENTLOST;
		//CloseHandle(mmf);
		UnmapViewOfFile(linkmem);
		CloseHandle(mmf);
		//linkmem = NULL;
	}

	for(i=0;i<5;i++){ //i<4
		if(linksync[i]!=NULL){
			PulseEvent(linksync[i]);
			CloseHandle(linksync[i]);
		}
	}
	regSetDwordValue("LAN", lanlink.active);
	closesocket(lanlink.tcpsocket);
	WSACleanup();
	return;
}

// Server
lserver::lserver(void){
	intinbuffer = (int*)inbuffer;
	u16inbuffer = (u16*)inbuffer;
	u32inbuffer = (u32*)inbuffer;
	intoutbuffer = (int*)outbuffer;
	u16outbuffer = (u16*)outbuffer;
	u32outbuffer = (u32*)outbuffer;
	oncewait = false;
}

int lserver::Init(void *serverdlg){
	SOCKADDR_IN info;
	DWORD nothing;
	char str[100];
	unsigned long notblock = 1; //0=blocking, non-zero=non-blocking

	info.sin_family = AF_INET;
	info.sin_addr.S_un.S_addr = INADDR_ANY;
	info.sin_port = htons(5738);

	ioctlsocket(lanlink.tcpsocket, FIONBIO, &notblock); //use non-blocking mode?

	if(lanlink.thread!=NULL){
		c_s.Lock(); //AdamN: Locking resource to prevent deadlock
		lanlink.terminate = true;
		c_s.Unlock(); //AdamN: Unlock it after use
		Sleep(linktimeout+100);
		//WaitForSingleObject(linksync[vbaid], 2000); //500
		lanlink.thread = NULL;
		//SetEvent(linksync[vbaid]); //should it be reset?
	}
	lanlink.terminate = false;

	CloseLink(); //AdamN: close connections gracefully
	InitLink(); //AdamN: reinit sockets
	outsize = 0;
	insize = 0;
	initd = 0;

	//notblock = 1; //0;
	//ioctlsocket(lanlink.tcpsocket, FIONBIO, &notblock); //AdamN: need to be blocking mode? It seems Server Need to be in Non-blocking mode

	if(bind(lanlink.tcpsocket, (LPSOCKADDR)&info, sizeof(SOCKADDR_IN))==SOCKET_ERROR){
		closesocket(lanlink.tcpsocket);
		if((lanlink.tcpsocket=socket(AF_INET, SOCK_STREAM, IPPROTO_TCP))==INVALID_SOCKET)
			return errno;
		if(bind(lanlink.tcpsocket, (LPSOCKADDR)&info, sizeof(SOCKADDR_IN))==SOCKET_ERROR)
			return errno;
	}

	if(listen(lanlink.tcpsocket, lanlink.numgbas)==SOCKET_ERROR)
		return errno;

	linkid = 0;

	gethostname(str, 100);
	int i = 0;
	CString stringb = _T("");
	if (gethostbyname(str)->h_addrtype == AF_INET) {
            while (gethostbyname(str)->h_addr_list[i] != 0) {
				stringb.AppendFormat(_T("%s/"), inet_ntoa(*(LPIN_ADDR)(gethostbyname(str)->h_addr_list[i++]))); //AdamN: trying to shows all IP that was binded
			}
			if(stringb.GetLength()>0)
				stringb.Delete(stringb.GetLength()-1);
	}
	((ServerWait*)serverdlg)->m_serveraddress.Format(_T("Server IP address is: %s"), (LPCTSTR)stringb /*inet_ntoa(*(LPIN_ADDR)(gethostbyname(str)->h_addr_list[0]))*/);
	
	lanlink.thread = CreateThread(NULL, 0, LinkServerThread, serverdlg, 0, &nothing);

	return 0;

}

DWORD WINAPI LinkServerThread(void *serverdlg){ 
	fd_set fdset;
	timeval wsocktimeout;
	SOCKADDR_IN info;
	int infolen;
	char inbuffer[256], outbuffer[256];
	int *intinbuffer = (int*)inbuffer;
	u16 *u16inbuffer = (u16*)inbuffer;
	int *intoutbuffer = (int*)outbuffer;
	u16 *u16outbuffer = (u16*)outbuffer;
	BOOL disable = true;
	DWORD timeout = linktimeout;
	int sz = linkbuffersize; //32767;
	DWORD nothing;
	unsigned long notblock = 1; //0=blocking, non-zero=non-blocking

	for(int j=0; j<5; j++)
		ls.connected[j] = false;

	wsocktimeout.tv_sec = 1; //linktimeout / 1000; //1;
	wsocktimeout.tv_usec = 0; //linktimeout % 1000; //0;
	i = 0;
	BOOL shown = true;

	while(shown && i<lanlink.numgbas){ //AdamN: this may not be thread-safe //is it should be i<lanlink.numgbas ?
		fdset.fd_count = 1;
		fdset.fd_array[0] = lanlink.tcpsocket;
		int sel = select(0, &fdset, NULL, NULL, &wsocktimeout); 
		if(sel>0){ //AdamN: output from select can also be SOCKET_ERROR, it seems ServerWait window got stucked when Cancel pressed because select will only return 1 if a player connected
		    c_s.Lock(); //AdamN: Locking resource to prevent deadlock
			bool canceled=lanlink.terminate;
			c_s.Unlock(); //AdamN: Unlock it after use
			if(canceled){ //AdamN: check if ServerWait was Canceled, might not be thread-safe
				//SetEvent(linksync[vbaid]); //AdamN: i wonder what is this needed for?
				//return 0; //AdamN: exiting the thread here w/o closing the ServerWait window will cause the window to be stucked
				break;
			}
			if((ls.tcpsocket[i+1]=accept(lanlink.tcpsocket, NULL, NULL))==INVALID_SOCKET){
				for(int j=1;j<i;j++) closesocket(ls.tcpsocket[j]);
				MessageBox(NULL, _T("Network error."), _T("Error"), MB_OK);
				//return 1; //AdamN: exiting the thread here w/o closing the ServerWait window will cause the window to be stucked
				break;
			} else {
				setsockopt(ls.tcpsocket[i+1], IPPROTO_TCP, TCP_NODELAY, (char*)&disable, sizeof(BOOL)); //true=send packet immediately
				setsockopt(ls.tcpsocket[i+1], SOL_SOCKET, SO_RCVTIMEO, (char*)&timeout, sizeof(DWORD)); //setting recv timeout
				setsockopt(ls.tcpsocket[i+1], SOL_SOCKET, SO_SNDTIMEO, (char*)&timeout, sizeof(DWORD)); //setting send timeout
				setsockopt(ls.tcpsocket[i+1], SOL_SOCKET, SO_RCVBUF, (char*)&sz, sizeof(int)); //setting recv buffer
				/*notblock = 1;
				ioctlsocket(ls.tcpsocket[i+1], FIONBIO, &notblock); //AdamN: need to be in non-blocking mode?*/
				outbuffer[0] = 4;
				outbuffer[1] = i+1;
				u16outbuffer[1] = lanlink.numgbas; //lanlink.numgbas+1;
				DWORD lat = GetTickCount();
				send(ls.tcpsocket[i+1], outbuffer, 4, 0); //Sending index and #gba to client
				lat = GetTickCount() - lat;
				infolen = sizeof(SOCKADDR_IN);
				getpeername(ls.tcpsocket[i+1], (LPSOCKADDR)&info , &infolen);
				ls.connected[i+1] = true;
				if(serverdlg && IsWindow(((ServerWait*)serverdlg)->GetSafeHwnd()/*m_hWnd*/)) { //AdamN: not really useful for UpdateData
					((ServerWait*)serverdlg)->m_plconn[i].Format(_T("Client %d connected  (IP: %s, Latency: %dms)"), i+1, inet_ntoa(info.sin_addr), lat);
					CWnd *tmpwnd = NULL;
					//((ServerWait*)serverdlg)->UpdateData(false); //AdamN: this seems to cause 2 assertion failed errors when a player connected, seems to be not thread-safe
					//((ServerWait*)waitdlg)->UpdateData(false); //AdamN: refreshing static text after being modified above, may not be thread-safe (causing assertion failed)
					tmpwnd = ((ServerWait*)serverdlg)->GetDlgItem(IDC_STATIC1);
					if(tmpwnd && IsWindow(tmpwnd->GetSafeHwnd()/*m_hWnd*/)) tmpwnd->SetWindowText((LPCTSTR)((ServerWait*)serverdlg)->m_serveraddress); //((ServerWait*)serverdlg)->Invalidate(); //((ServerWait*)serverdlg)->SendMessage(WM_PAINT, 0, 0); //AdamN: using message might be safer than UpdateData but might not works
					tmpwnd = ((ServerWait*)serverdlg)->GetDlgItem(IDC_STATIC2);
					if(tmpwnd && IsWindow(tmpwnd->GetSafeHwnd()/*m_hWnd*/)) tmpwnd->SetWindowText((LPCTSTR)((ServerWait*)serverdlg)->m_plconn[0]); //m_plconn[0]
					tmpwnd = ((ServerWait*)serverdlg)->GetDlgItem(IDC_STATIC3);
					if(tmpwnd && IsWindow(tmpwnd->GetSafeHwnd()/*m_hWnd*/)) tmpwnd->SetWindowText((LPCTSTR)((ServerWait*)serverdlg)->m_plconn[1]); //m_plconn[1]
					tmpwnd = ((ServerWait*)serverdlg)->GetDlgItem(IDC_STATIC4);
					if(tmpwnd && IsWindow(tmpwnd->GetSafeHwnd()/*m_hWnd*/)) tmpwnd->SetWindowText((LPCTSTR)((ServerWait*)serverdlg)->m_plconn[2]); //m_plconn[2]
					tmpwnd = ((ServerWait*)serverdlg)->GetDlgItem(IDC_STATIC5);
					if(tmpwnd && IsWindow(tmpwnd->GetSafeHwnd()/*m_hWnd*/)) tmpwnd->SetWindowText((LPCTSTR)((ServerWait*)serverdlg)->m_plconn[3]); //m_plconn[3]
					//((ServerWait*)serverdlg)->GetDlgItem(IDC_SERVERWAIT)->Invalidate(); //m_prgctrl
					((ServerWait*)serverdlg)->Invalidate();
				}
				i++;
			}
		}

		//TODO: check for previously connected clients who got disconnected and try to connect again, and preventing 1 player from using more than 1 player slots (making server to think all players already connected while it's not)

		shown = (serverdlg && IsWindow(((ServerWait*)serverdlg)->GetSafeHwnd()/*m_hWnd*/)); //AdamN: trying to detect when Cancel button pressed (which cause Waiting for Player window to be closed)
		if(shown) {
			((ServerWait*)serverdlg)->m_prgctrl.StepIt(); //AdamN: this will cause assertion failed if the Waiting for Player window is Canceled
		}
		c_s.Lock(); //AdamN: Locking resource to prevent deadlock
		bool canceled=lanlink.terminate; //AdamN: w/o locking might not be thread-safe
		c_s.Unlock(); //AdamN: Unlock it after use
		if(canceled) break;
	}
	
	if(i>0) { //AdamN: if canceled after 1 or more player has been connected link will stil be marked as connected
		MessageBox(NULL, _T("All players connected"), _T("Link"), MB_OK);
		c_s.Lock(); //AdamN: Locking resource to prevent deadlock
		lanlink.numgbas = i; //i+1; //AdamN: update # of GBAs according to connected players before server got canceled
		c_s.Unlock(); //AdamN: Unlock it after use
	}
	if(shown) {
	    ((ServerWait*)serverdlg)->SendMessage(WM_CLOSE, 0, 0); //AdamN: this will also cause assertion failed if the Waiting for Player window was Canceled/no longer existed
	}

	shown = (i>0); //AdamN: if canceled after 1 or more player has been connected connecteion will still be established
	for(i=1;i<=lanlink.numgbas;i++){ //AdamN: this should be i<lanlink.numgbas isn't?(just like in the while above), btw it might not be thread-safe (may be i'm being paranoid)
		outbuffer[0] = 4;
		send(ls.tcpsocket[i], outbuffer, 4, 0);
	}
	
	if(shown) { //AdamN: if one or more players connected before server got canceled connecteion will still be established
		c_s.Lock(); //AdamN: Locking resource to prevent deadlock
		lanlink.connected = true;
		c_s.Unlock(); //AdamN: Unlock it after use
	}
	/*else*/ //SetEvent(linksync[vbaid]); //AdamN: saying the lanlink.thread is exiting? might cause thread to stuck when app exited

	c_s.Lock();
	if(lanlink.connected) {
		lanlink.terminate = false;
		lanlink.thread = CreateThread(NULL, 0, LinkHandlerThread, NULL, 0, &nothing); //AdamN: trying to reduce the lag by handling sockets in a different thread, not working properly yet
	}
	c_s.Unlock();
	vbaid = 0; //server might expect to have vbaid=0 in some part of the code
	linkid = vbaid;

	return 0;
}

DWORD WINAPI LinkHandlerThread(void *param){ //AdamN: Trying to reduce the lag by handling sockets in a different thread, but doesn't works quite right
	//SetEvent(linksync[vbaid]); //AdamN: will cause VBA-M to stuck in memory after exit
	//return 0; //this thread currently not used due to not thread-safe yet
	
	//LINKCMDPRM cmdprm;
	//ULONG tmp;
	rfu_datarec tmpRec;
	static char inbuf[8192]; //8192
	static char outbuf[4];
	u32 *u32outbuf = (u32*)outbuf;
	u16 *u16inbuf = (u16*)inbuf;
	u32 *u32inbuf = (u32*)inbuf;
	static int insize;
	//u16 tmpid, idmask;
	u32 tmpq; //u8
	//DWORD tmpTime;
	bool ok = false;
	int idx, i;
	bool done = false;

	c_s.Lock();
	LinkHandlerActive = true;
	idx = gbaid;
	c_s.Unlock();
	u32 lasttm = GetTickCount();
	while (/*c_s!=0 &&*/ !done) {
		//AdamN: Locking cs might cause an exception if application closed down while the thread still running
		//if(gba_link_auto && gba_joybus_enabled) if (!dol) JoyBusConnect(); //may cause lags
		//if (rfu_enabled && lanlink.connected) //only for wireless emulation through network being handled, to prevent reading data which was waited by cable linking emulation
		while (rfu_enabled && /*lanlink.connected*/IsLinkConnected() && LinkIsDataReady(&idx)) {
			if (idx!=vbaid && lanlink.connected)
			if (LinkRecvData(inbuf,2,idx,true))
			if (inbuf[1] == -32 /*&& (inbuf[0]==4 || inbuf[0]==12)*/) { //-32 (0xe0) = disconnecting id
				if(vbaid) LinkConnected(false); else
				{
					c_s.Lock();
					ls.connected[idx] = false;
					lanlink.connected = IsLinkConnected();
					c_s.Unlock();
				}
				LinkDiscardData(idx);
			} else 
			if ((inbuf[0]>3) && ((inbuf[1] & 0xc0) == 0x80)) { //inbuf[1]=='W' //wireless header ID
				LinkRecvData(inbuf,4,idx);
				u8 gid = idx; //inbuf[1]; //source id
				u8 tid = inbuf[1] & 0x3f; //destination id, if tid==gid then it's a broadcast from client (server may need to bridge broadcast from client to client)
				u8 cmd = inbuf[2];
				int size = inbuf[3]; //in 32bit words
				u32outbuf[0] = u32inbuf[0];
				/*if(cmd==0x24 || cmd==0x25 || cmd==0x35) {
					LinkRecvData(inbuf,4,idx);
					linktime2 = u32inbuf[0];
				}*/
				if (size>0)
				LinkRecvData(inbuf,size*4,idx);
				//check whether this GBA should accept the packet or forward it to other GBA
				if(tid!=vbaid && tid!=gid) { //not for this GBA and not a broadcast = targeted only to another GBA
					if(vbaid==0 && ls.connected[tid]) { //bridging can only be done through server
						LinkSendData(outbuf,4,RetryCount,tid);
						if(size>0)
						LinkSendData(inbuf,size*4,RetryCount,tid);
					}
				} else { //targeted for this GBA or a broadcast
				if(vbaid==0) { //bridging can only be done through server
					if(tid==gid) { //broadcast to other clients (excluding server & sender)
						for(i=1; i<=lanlink.numgbas; i++)
						if(i!=gid && ls.connected[i]) {
							LinkSendData(outbuf,4,RetryCount,i);
							if(size>0)
							LinkSendData(inbuf,size*4,RetryCount,i);
						}
					}
				}
				if(ioMem) {
				c_s.Lock();
				u16 siocnt = READ16LE(&ioMem[COMM_SIOCNT]);
				c_s.Unlock();
				if(siocnt)
				if(cmd==0x3d || GetSIOMode(siocnt, READ16LE(&ioMem[COMM_RCNT]))==NORMAL32)
				switch(cmd) { //data processing for this GBA
				case 0x16:
					//WaitForSingleObject(linksync[gid], linktimeout);
					c_s.Lock();
					//ResetEvent(linksync[gid]);
					memset(&linkmem->rfu_bdata[gid][1],0,sizeof(linkmem->rfu_bdata[gid])-4);
					//linkmem->rfu_bdata[gid][0] = (vbaid<<3)+0x61f1; //client id who want to join a host //shouldn't broadcast it yet?
					memcpy(&linkmem->rfu_bdata[gid][1],inbuf,size*4); //only use 6 dwords for the name (since 1st dwords used for ID)
					//SetEvent(linksync[gid]);
					c_s.Unlock();
					break;

				case 0x17:
					//WaitForSingleObject(linksync[gid], linktimeout);
					c_s.Lock();
					//ResetEvent(linksync[gid]);
					linkmem->rfu_gdata[gid] = u16inbuf[0]; //game id
					//SetEvent(linksync[gid]);
					c_s.Unlock();
					break;

				case 0x19:
				case 0x1b:
					//WaitForSingleObject(linksync[gid], linktimeout);
					c_s.Lock();
					//ResetEvent(linksync[gid]);
					linkmem->rfu_bdata[gid][0] = u16inbuf[0]; //adapter id
					linkmem->rfu_clientidx[gid] = 0; //host index is 0
					//SetEvent(linksync[gid]);
					c_s.Unlock();
					break;

				case 0x1a:
					//WaitForSingleObject(linksync[gid], linktimeout);
					c_s.Lock();
					//ResetEvent(linksync[gid]);
					linkmem->numgbas = lanlink.numgbas+1;
					linkmem->rfu_signal[gid] = u32inbuf[0];
					if(linkmem->rfu_signal[vbaid] && linkmem->rfu_signal[vbaid]<u32inbuf[0]) linkmem->rfu_signal[vbaid] = u32inbuf[0];
					if((u32inbuf[1]&0xffff) == ((vbaid<<3)+0x61f1)) { //adapter id
						linkmem->rfu_signal[vbaid] = u32inbuf[0];
						linkmem->rfu_clientidx[vbaid] = u32inbuf[1]>>16;
						linkmem->rfu_clientidx[gid] = 0; //host index is 0
					}
					//SetEvent(linksync[gid]);
					c_s.Unlock();
					break;

				case 0x1f:
					//WaitForSingleObject(linksync[gid], linktimeout);
					c_s.Lock();
					//ResetEvent(linksync[gid]);
					linkmem->rfu_reqid[gid] = u16inbuf[0]; //(rfu_id-0x61f1)>>3
					linkmem->rfu_request[tid] |= (1<<gid); //4; //true, id data is fresh/not received by server yet
					//SetEvent(linksync[gid]);
					c_s.Unlock();
					//rfu_id = u16inbuf[2];
					//gbaid = (rfu_id-0x61f1)>>3;
					//rfu_idx = rfu_id;
					break;

				case 0x24:
				case 0x25:
				case 0x35:
				case 0x27:
				case 0x37:
					//Sleep(100); //simulating 100ms latency?
					//linkmem->numgbas = lanlink.numgbas+1;
					//idmask = (0xffff>>(16-linkmem->numgbas))^(1<<gid);
					//if((numtransfers++)==0) linktime = 1; //numtransfers doesn't seems to be used?
					//WaitForSingleObject(linksync[gid], linktimeout);
					c_s.Lock();
					//ResetEvent(linksync[gid]); //mark it as unread/unreceived data
					//linkmem->rfu_linktime[gid] = u32inbuf[0]; //linktime
					tmpq = size-2; //linkmem->rfu_q[gid] = size-1; //linkmem->rfu_q[vbaid]
					//if(tmpq)
					if(tmpq>1 || DATALIST.empty()) {
						//memcpy(linkmem->rfu_data[gid],inbuf+4,(size-1)<<2);
						//linkmem->rfu_qid[gid] = (1<<vbaid); //rfu_id; //0; //rfu_id; //mark the id to whom the data for, 0=broadcast to all connected gbas
						if(tmpq>0)
						memcpy(tmpRec.data,&u32inbuf[2],tmpq<<2);
						tmpRec.sign = u32inbuf[0];
						tmpRec.time = u32inbuf[1];
						tmpRec.qid = (1<<vbaid); //linkmem->rfu_qid[gid];
						tmpRec.len = tmpq;
						tmpRec.gbaid = gid;
						tmpRec.idx = (u8)linkmem->rfu_clientidx[gid];
						/*if(tmpRec.idx>4) { //TODO: How did client index became 0xf0 sometimes ??
							log("Client Index of %d[%d] = %02X\n", gid, rfu_ishost, tmpRec.idx);
							tmpRec.idx = 0;
						}*/
						DATALIST.push_back(tmpRec);
					}
					//SetEvent(linksync[gid]);
					c_s.Unlock();
					//should we reply to sender to tell them that the data has been received? just in case they're waiting before sending another data
					break;

				/*case 0x27:
				case 0x37:
					//WaitForSingleObject(linksync[gid], linktimeout);
					c_s.Lock();
					//ResetEvent(linksync[gid]); //mark it as unread/unreceived data
					linkmem->rfu_linktime[gid] = u32inbuf[0]; //linktime
					//SetEvent(linksync[gid]);
					c_s.Unlock();
					break;*/

				case 0x3d:
					c_s.Lock();
					linkmem->rfu_q[gid] = 0;
					linkmem->rfu_request[gid] = 0;
					linkmem->rfu_signal[gid] = 0;
					c_s.Unlock();
					LinkDiscardData(gid);
					break;
				}
				c_s.Lock();
				if(cmd && ioMem) 
				UPDATE_REG(RF_RECVCMD, cmd);
				c_s.Unlock();
				}
				}
			}

			u32 curtm = GetTickCount();
			if(curtm-lasttm>164) { //let the CPU rest abit on continuous stream of data
				SleepEx(1,true);
				lasttm = curtm;
			}
		}

		/*c_s.Lock(); //AdamN: Locking resource to prevent deadlock
		int LinkCmd=LinkCommand;
		cmdprm.Command = 0;
		if(LinkCmdList.GetCount()>0) {
		tmp = (ULONG)*&LinkCmdList.GetHead();
		cmdprm.Command = tmp & 0xffff;
		cmdprm.Param = tmp >> 16;
		//log("Rem: %04X %04X\n",cmdprm.Command,cmdprm.Param); //AdamN: calling "log" in here seems to cause deadlock
		LinkCmdList.RemoveHead();
		}
		c_s.Unlock(); //AdamN: Locking resource to prevent deadlock
		LinkCmd = cmdprm.Command;
		if(LinkCmd & 1) { //StartLink
			int prm = cmdprm.Param; //LinkParam1;
			StartLink2(prm); //AdamN: Might not be thread-safe w/o proper locking inside StartLink
			c_s.Lock();
			LinkCommand&=0xfffffffe;
			c_s.Unlock();
		}
		if(LinkCmd & 2) { //StartGPLink, might not be needed as it doesn't use socket
			int prm = cmdprm.Param; //LinkParam2;
			StartGPLink(prm); //AdamN: Might not be thread-safe w/o proper locking inside StartLink
			c_s.Lock();
			LinkCommand&=0xfffffffd;
			c_s.Unlock();
		}
		if(LinkCmd & 4) { //StartRFU, might not be needed as it doesn't use socket currently
			int prm = cmdprm.Param; //LinkParam4;
			StartRFU(prm); //AdamN: Might not be thread-safe w/o proper locking inside StartLink
			c_s.Lock();
			LinkCommand&=0xfffffffb;
			c_s.Unlock();
		}
		if(LinkCmd & 8) { //LinkUpdate
			int prm = cmdprm.Param; //LinkParam8;
			LinkUpdate2(prm, 0); //AdamN: Might not be thread-safe w/o proper locking inside StartLink
			c_s.Lock();
			LinkCommand&=0xfffffff7;
			c_s.Unlock();
		}*/
		SleepEx(1,true);

		/*c_s.Lock();
		done=(lanlink.connected && linkid&&lc.numtransfers==0);
		c_s.Unlock();
		if(done) lc.CheckConn();*/

		c_s.Lock();
		done=(/*lanlink.terminate &&*/ AppTerminated || !lanlink.connected);
		idx = gbaid;
		c_s.Unlock();
	}
	//SetEvent(linksync[vbaid]);
	c_s.Lock();
	LinkHandlerActive = false;
	c_s.Unlock();
	return 0;
}

BOOL lserver::Send(void){
	//return false;
	BOOL sent = false;
	BOOL disable = true; //true=send packet immediately
	if(lanlink.type==0){	// TCP
		if(savedlinktime==-1){
			outbuffer[0] = 4;
			outbuffer[1] = -32;	//0xe0 //Closing mark?
			for(i=1;i<=lanlink.numgbas;i++){
				unsigned long notblock = 0; //0=blocking, non-zero=non-blocking
				ioctlsocket(tcpsocket[i], FIONBIO, &notblock); //AdamN: use blocking for sending to prevent partially sent data
				//setsockopt(tcpsocket[i], IPPROTO_TCP, TCP_NODELAY, (char*)&disable, sizeof(BOOL)); //true=send packet immediately
				#ifdef GBA_LOGGING
					if(systemVerbose & VERBOSE_LINK) {
						log("%sSS1\n",(LPCTSTR)LogStr);
						log("SSend to : %d  Size : %d  %s\n", i, 4, (LPCTSTR)DataHex(outbuffer,4));
					}
				#endif
				if(send(tcpsocket[i], outbuffer, 4, 0)!=SOCKET_ERROR) { //AdamN: should check for socket error to reduce the lag
					//sent = true;
					unsigned long notblock = 1; //0=blocking, non-zero=non-blocking
					ioctlsocket(tcpsocket[i], FIONBIO, &notblock); //AdamN: use blocking for receiving
					int cnt=recv(tcpsocket[i], inbuffer, 1, 0); //is the data important? as it's going to be disconnected anyways
					if(cnt>0) cnt += recv(tcpsocket[i], inbuffer+cnt, inbuffer[0]-cnt, 0);
					#ifdef GBA_LOGGING
						if(systemVerbose & VERBOSE_LINK) {
							log("%sSS2\n",(LPCTSTR)LogStr);
							log("Srecv from : %d  Size : %d  %s\n", i, cnt, (LPCTSTR)DataHex(inbuffer,cnt));
						}
					#endif
				}
			}
			//return sent;
		}
		for(i=1; i<=lanlink.numgbas; i++) {
			unsigned long notblock = 0; //0=blocking, non-zero=non-blocking
			ioctlsocket(tcpsocket[i], FIONBIO, &notblock); //AdamN: use blocking for sending to prevent partially sent data
			//setsockopt(tcpsocket[i], IPPROTO_TCP, TCP_NODELAY, (char*)&disable, sizeof(BOOL)); //true=send packet immediately
		}
		//Broadcasting data to all GBAs
		outbuffer[1] = tspeed;
		u16outbuffer[1] = linkdata[0];
		intoutbuffer[1] = savedlinktime;
		if(lanlink.numgbas==1){ //2 players
			if(lanlink.type==0){ //TCP
				outbuffer[0] = 8; 
				#ifdef GBA_LOGGING
					if(systemVerbose & VERBOSE_LINK) {
						log("%sSS3\n",(LPCTSTR)LogStr);
						log("SSend to : %d  Size : %d  %s\n", 1, 8, (LPCTSTR)DataHex(outbuffer,8));
					}
				#endif
				sent=(send(tcpsocket[1], outbuffer, 8, 0)>=0);
				int ern=errno;
				if(ern!=0 && ern!=lastern[1]) {
					if(ern!=10035 && ern!=10060) {c_s.Lock(); connected[1] = false; lanlink.connected = IsLinkConnected(); c_s.Unlock();}
					log("[SS1]WSAError1 = %d [%d]\n",ern,lastern[1]);
					lastern[1] = ern;
				}
			}
		}
		else if(lanlink.numgbas==2){ //3 players
			u16outbuffer[4] = linkdata[2];
			if(lanlink.type==0){ //TCP
				outbuffer[0] = 10;
				#ifdef GBA_LOGGING
					if(systemVerbose & VERBOSE_LINK) {
						log("%sSS4\n",(LPCTSTR)LogStr);
						log("SSend to : %d  Size : %d  %s\n", 1, 10, (LPCTSTR)DataHex(outbuffer,10));
					}
				#endif
				sent=(send(tcpsocket[1], outbuffer, 10, 0)>=0);
				int ern=errno;
				if(ern!=0 && ern!=lastern[1]) {
					if(ern!=10035 && ern!=10060) {c_s.Lock(); connected[1] = false; lanlink.connected = IsLinkConnected(); c_s.Unlock();}
					log("[SS2]WSAError1 = %d [%d]\n",ern,lastern[1]);
					lastern[1] = ern;
				}
				u16outbuffer[4] = linkdata[1];
				#ifdef GBA_LOGGING
					if(systemVerbose & VERBOSE_LINK) {
						log("%sSS5\n",(LPCTSTR)LogStr);
						log("SSend to : %d  Size : %d  %s\n", 2, 10, (LPCTSTR)DataHex(outbuffer,10));
					}
				#endif
				sent&=(send(tcpsocket[2], outbuffer, 10, 0)>=0);
				ern=errno;
				if(ern!=0 && ern!=lastern[2]) {
					if(ern!=10035 && ern!=10060) {c_s.Lock(); connected[2] = false; lanlink.connected = IsLinkConnected(); c_s.Unlock();}
					log("[SS3]WSAError2 = %d [%d]\n",ern,lastern[2]); 
					lastern[2] = ern;
				}
			}
		} else { //4 players
			if(lanlink.type==0){ //TCP
				outbuffer[0] = 12;
				u16outbuffer[4] = linkdata[2];
				u16outbuffer[5] = linkdata[3];
				#ifdef GBA_LOGGING
					if(systemVerbose & VERBOSE_LINK) {
						log("%sSS6\n",(LPCTSTR)LogStr);
						log("SSend to : %d  Size : %d  %s\n", 1, 12, (LPCTSTR)DataHex(outbuffer,12));
					}
				#endif
				sent=(send(tcpsocket[1], outbuffer, 12, 0)>=0);
				int ern=errno;
				if(ern!=0 && ern!=lastern[1]) {
					if(ern!=10035 && ern!=10060) {c_s.Lock(); connected[1] = false; lanlink.connected = IsLinkConnected(); c_s.Unlock();}
					log("[SS4]WSAError1 = %d [%d]\n",ern,lastern[1]); 
					lastern[1] = ern;
				}
				u16outbuffer[4] = linkdata[1];
				#ifdef GBA_LOGGING
					if(systemVerbose & VERBOSE_LINK) {
						log("%sSS7\n",(LPCTSTR)LogStr);
						log("SSend to : %d  Size : %d  %s\n", 2, 12, (LPCTSTR)DataHex(outbuffer,12));
					}
				#endif
				sent&=(send(tcpsocket[2], outbuffer, 12, 0)>=0);
				ern=errno;
				if(ern!=0 && ern!=lastern[2]) {
					if(ern!=10035 && ern!=10060) {c_s.Lock(); connected[2] = false; lanlink.connected = IsLinkConnected(); c_s.Unlock();}
					log("[SS5]WSAError2 = %d [%d]\n",ern,lastern[2]); 
					lastern[2] = ern;
				}
				u16outbuffer[5] = linkdata[2];
				#ifdef GBA_LOGGING
					if(systemVerbose & VERBOSE_LINK) {
						log("%sSS8\n",(LPCTSTR)LogStr);
						log("SSend to : %d  Size : %d  %s\n", 3, 12, (LPCTSTR)DataHex(outbuffer,12));
					}
				#endif
				sent&=(send(tcpsocket[3], outbuffer, 12, 0)>=0);
				ern=errno;
				if(ern!=0 && ern!=lastern[3]) {
					if(ern!=10035 && ern!=10060) {c_s.Lock(); connected[3] = false; lanlink.connected = IsLinkConnected(); c_s.Unlock();}
					log("[SS6]WSAError3 = %d [%d]\n",ern,lastern[3]); 
					lastern[3] = ern;
				}
			}
		}
	}
	if(sent) initd++;
	return sent;
}

BOOL lserver::Recv(void){
	//return false;
	BOOL recvd = false;
	BOOL disable = true;
	unsigned long arg = 0;

	int numbytes;
	if(lanlink.type==0){	// TCP
		wsocktimeout.tv_sec = linktimeout / 1000; //AdamN: setting this too small may cause disconnection in game, too large will cause great lag
		wsocktimeout.tv_usec = linktimeout % 1000; //0; //AdamN: remainder should be set also isn't?
		//FD_ZERO(&fdset);
		fdset.fd_count = lanlink.numgbas; //not lanlink.numgbas+1; because it's started from 1 instead of 0
		for(i=1;i<=lanlink.numgbas;i++) { //i<=lanlink.numgbas
			fdset.fd_array[i-1] = tcpsocket[i]; //FD_SET(tcpsocket[i], &fdset);
			unsigned long notblock = 0; //0=blocking, non-zero=non-blocking
			ioctlsocket(tcpsocket[i], FIONBIO, &notblock); //AdamN: use non-blocking for checking
		}

		/*int cnt=0;
		for(i=0;i<lanlink.numgbas;i++) {
			arg = 0;
			if(ioctlsocket(tcpsocket[i+1], FIONREAD, &arg)!=0) { //Faster alternative than Select but doesn't seems to works as good as Select
				int ern=errno; //AdamN: this seems to get ern=10038(invalid socket handle) often
				if(ern!=0)
				log("%sSR1-%d[%d]\n",(LPCTSTR)LogStr,i,ern);
				continue; //break;
			} else if(arg>0) cnt++;
		}
		if(cnt<=0) return recvd;*/
		
		if(select(0, &fdset, NULL, NULL, &wsocktimeout)<=0 ){ //AdamN: may cause noticible delay, result can also be SOCKET_ERROR, Select seems to be needed to maintain stability
			int ern=errno; //may cause error 10038(invalid socket handle) when using non-blocking sockets
			if(ern!=0)
			log("%sSR1[%d]\n",(LPCTSTR)LogStr,ern); //AdamN: seems to be getting 3x timeout when multiplayer established in game
			return recvd;
		}

		howmanytimes++;
		for(i=1;i<=lanlink.numgbas;i++){
			arg = 0;
			if(ioctlsocket(tcpsocket[i], FIONREAD, &arg)!=0) { //check for available data
				int ern=errno; //AdamN: this seems to get ern=10038(invalid socket handle) often
				if(ern!=0)
				log("%sSR1-%d[%d]\n",(LPCTSTR)LogStr,i,ern);
				continue; //break;
			}
			unsigned long notblock = 1; //0=blocking, non-zero=non-blocking
			ioctlsocket(tcpsocket[i], FIONBIO, &notblock); //AdamN: use blocking for receiving
			numbytes = 0;
			inbuffer[0] = 1;
			while(numbytes<howmanytimes*inbuffer[0]) {
				int cnt = recv(tcpsocket[i], inbuffer+numbytes, /*256*/(howmanytimes*inbuffer[0])-numbytes, 0);
				if(cnt<=0) break; //==SOCKET_ERROR //AdamN: to prevent stop responding due to infinite loop on socket error
				numbytes += cnt;
				/*#ifdef GBA_LOGGING
					if(systemVerbose & VERBOSE_LINK) {
						log("%sSR2\n",(LPCTSTR)LogStr);
						log("SRecv from : %d  Size : %d  %s\n", i+1, cnt, (LPCTSTR)DataHex(inbuffer,cnt));
					}
				#endif*/
			}
			#ifdef GBA_LOGGING
					if(systemVerbose & VERBOSE_LINK) {
						log("%sSR2\n",(LPCTSTR)LogStr);
						log("SRecv from : %d  Size : %d  %s\n", i, numbytes, (LPCTSTR)DataHex(inbuffer,numbytes));
					}
			#endif
			recvd=(errno==0);
			if(howmanytimes>1) memcpy(inbuffer, inbuffer+inbuffer[0]*(howmanytimes-1), inbuffer[0]);
			if(inbuffer[1]==-32 /*|| errno!=0*/){ //AdamN: Should be checking for possible of socket error isn't?
				char message[30];
				{c_s.Lock(); connected[i] = false; lanlink.connected = IsLinkConnected(); c_s.Unlock();}
				sprintf(message, _T("Client %d disconnected gracefully."), i);
				MessageBox(NULL, message, _T("Link"), MB_OK);
				outbuffer[0] = 12; //4; //is this suppose to be 12?
				outbuffer[1] = -32;
				for(j=1;j<=lanlink.numgbas;j++){ //i<lanlink.numgbas
					unsigned long notblock = 0; //0=blocking, non-zero=non-blocking
					ioctlsocket(tcpsocket[j], FIONBIO, &notblock); //AdamN: use blocking for sending
					//setsockopt(tcpsocket[j], IPPROTO_TCP, TCP_NODELAY, (char*)&disable, sizeof(BOOL)); //true=send packet immediately
					#ifdef GBA_LOGGING
						if(systemVerbose & VERBOSE_LINK) {
							log("%sSR3\n",(LPCTSTR)LogStr);
							log("Ssend to : %d  Size : %d  %s\n", j, 12, (LPCTSTR)DataHex(outbuffer,12));
						}
					#endif
					if(send(tcpsocket[j], outbuffer, 12, 0)!=SOCKET_ERROR) { //AdamN: should check for socket error to reduce the lag
					notblock = 1; //0=blocking, non-zero=non-blocking
					ioctlsocket(tcpsocket[j], FIONBIO, &notblock); //AdamN: use blocking for receiving
					int cnt=recv(tcpsocket[j], inbuffer, 1, 0); //is this incomming data really important since the socket will be closed? should we wait for it?
					if(cnt>0) cnt += recv(tcpsocket[j], inbuffer+cnt, inbuffer[0]-cnt, 0);
					#ifdef GBA_LOGGING
						if(systemVerbose & VERBOSE_LINK) {
							log("%sSR4\n",(LPCTSTR)LogStr);
							log("SRecv from : %d  Size : %d  %s\n", j, cnt, (LPCTSTR)DataHex(inbuffer,cnt));
						}
					#endif
					}
					closesocket(tcpsocket[j]);
				}
				recvd=(errno==0);
				return recvd;
			}
			linkdata[i] = u16inbuffer[1];
		}
		howmanytimes = 0;
	}
	after = false;
	if (recvd) initd--;
	return recvd;
}

BOOL lserver::SendData(int size, int nretry, int idx){
	//return false;
	if(idx && !tcpsocket[idx]) return false;
	int sent = 0;
	BOOL disable = true; //true=send packet immediately
	BOOL sent2 = false;
	int ern = 0; //, lastern = 0;
	unsigned long notblock = 0; //1; //0=blocking, non-zero=non-blocking
	int i1 = 1, i2 = lanlink.numgbas;
	if(idx) {
		i1 = idx;
		i2 = idx;
	};
	for(int i=i1; i<=i2; i++) {
		ioctlsocket(tcpsocket[i], FIONBIO, &notblock); //AdamN: use non-blocking for sending to prevent getting timeout when socket's buffer is full
		//setsockopt(tcpsocket[i], IPPROTO_TCP, TCP_NODELAY, (char*)&disable, sizeof(BOOL)); //true=send packet immediately
		#ifdef GBA_LOGGING
			if(systemVerbose & VERBOSE_LINK) {
				//log("%sSS0%d\n",(LPCTSTR)LogStr, i);
				log("%sSSend0%d Size : %d  %s\n", (LPCTSTR)LogStr, i, size, (LPCTSTR)DataHex(outbuffer,size));
			}
		#endif
		int j = nretry; //+1;
		int sz = size;
		while (sz>0 && connected[i] && j>=0) {
		do {
			DWORD lat = GetTickCount();
			sent=send(tcpsocket[i], outbuffer+(size-sz), sz, 0);
			latency[i] = GetTickCount() - lat;
			ern = errno;
			if(ern!=0) {
				if(ern!=10035 && ern!=10060) {
					if(j<=0) {c_s.Lock(); connected[i] = false; lanlink.connected = IsLinkConnected(); c_s.Unlock();}
				}
				if(ern!=lastern[i]) 
				log("%sSS Error: %d [%d] (%d/%d)  %d\n",(LPCTSTR)LogStr,ern,lastern[i],sz,size,GetTickCount());
				lastern[i] = ern;
			}
			if(!lanlink.connected) {
				char message[40];
				sprintf(message, _T("Client %d disconnected."), i);
				MessageBox(NULL, message, _T("Link"), MB_OK);
			}
			j--;
		} while (j>=0 && connected[i] && ern);
		sent2|=!ern;
		if(sent>0) sz -= sent;
		}
	}
	return (sent2); //sent;
}

BOOL lserver::SendData(const char *buf, int size, int nretry, int idx){
	//return false;
	if(idx && !tcpsocket[idx]) return false;
	int sent = 0;
	BOOL disable = true; //true=send packet immediately
	BOOL sent2 = false;
	int ern = 0; //, lastern = 0;
	unsigned long notblock = 0; //1; //0=blocking, non-zero=non-blocking (non-blocking might gets error 10035, while blocking might gets error 10060)
	int i1 = 1, i2 = lanlink.numgbas;
	if(idx) { //target not server
		i1 = idx;
		i2 = idx;
	};
	for(int i=i1; i<=i2; i++) {
		ioctlsocket(tcpsocket[i], FIONBIO, &notblock); //AdamN: use non-blocking for sending to prevent getting timeout when socket's buffer is full
		//setsockopt(tcpsocket[i], IPPROTO_TCP, TCP_NODELAY, (char*)&disable, sizeof(BOOL)); //true=send packet immediately
		#ifdef GBA_LOGGING
			if(systemVerbose & VERBOSE_LINK) {
				//log("%sSS0%d\n",(LPCTSTR)LogStr, i);
				log("%sSSend0%d Size : %d  %s\n", (LPCTSTR)LogStr, i, size, (LPCTSTR)DataHex(buf,size));
			}
		#endif
		int j = nretry; //+1;
		int sz = size;
		while (sz>0 && connected[i] && j>=0) {
		do {
			DWORD lat = GetTickCount();
			sent=send(tcpsocket[i], buf+(size-sz), sz, 0);
			latency[i] = GetTickCount() - lat;
			ern = errno;
			if(ern!=0) {
				if(ern!=10035 && ern!=10060) {
					if(j<=0) {c_s.Lock(); connected[i] = false; lanlink.connected = IsLinkConnected(); c_s.Unlock();}
				}
				if(ern!=lastern[i]) 
				log("%sSS Error: %d [%d] (%d/%d)  %d\n",(LPCTSTR)LogStr,ern,lastern[i],sz,size,GetTickCount());
				lastern[i] = ern;
			}
			if(!lanlink.connected) {
				char message[40];
				sprintf(message, _T("Client %d disconnected."), i);
				MessageBox(NULL, message, _T("Link"), MB_OK);
			}
			j--;
		} while (j>=0 && connected[i] && ern);
		sent2|=!ern;
		if(sent>0) sz -= sent;
		}
	}
	return (sent2); //sent;
}

BOOL lserver::RecvData(int size, int idx, bool peek){
	//return false;
	if(!tcpsocket[idx]) return false;
	BOOL recvd = false;
	BOOL disable = true;
	unsigned long notblock = 0; //0=blocking, non-zero=non-blocking
	ioctlsocket(tcpsocket[idx], FIONBIO, &notblock); //AdamN: use blocking for receiving
	setsockopt(tcpsocket[idx], IPPROTO_TCP, TCP_NODELAY, (char*)&disable, sizeof(BOOL)); //true=send packet immediately
	int flg = 0;
	if(peek) flg = MSG_PEEK;
	int rsz = size;
	if(connected[idx])
	do {
		int cnt=recv(tcpsocket[idx], inbuffer+(size-rsz), rsz, flg);
		if(cnt>=0) rsz-=cnt; else {c_s.Lock(); connected[idx] = false; lanlink.connected = IsLinkConnected(); c_s.Unlock();}
		int ern = errno;
		if(ern!=0) {
			if(ern!=lastern[idx]) {
				log("[SR]WSAError%d: %d %d\n",idx, ern, lastern[idx]); //TODO: getting timeout error 10060 often
				lastern[idx] = ern;
			}
			{c_s.Lock(); connected[idx] = false; lanlink.connected = IsLinkConnected(); c_s.Unlock();}
		}
		if(!lanlink.connected) {
			char message[40];
			sprintf(message, _T("Client %d disconnected. (err: %d)"), idx, ern);
			MessageBox(NULL, message, _T("Link"), MB_OK);
		}
	} while (rsz>0 && lanlink.connected);
	insize = size-rsz;
	recvd = (rsz<=0);
	#ifdef GBA_LOGGING
		if(systemVerbose & VERBOSE_LINK) {
			//log("%sSR0%d\n",(LPCTSTR)LogStr, idx);
			log("%sSRecv%d(%d) Size : %d/%d  %s\n", (LPCTSTR)LogStr, idx, peek, insize, size, (LPCTSTR)DataHex(inbuffer,size));
		}
	#endif
	return recvd;
}

int lserver::WaitForData(int ms) {
	unsigned long notblock = 1; //AdamN: 0=blocking, non-zero=non-blocking
	unsigned long arg = 0;
	//fd_set fdset;
	//timeval wsocktimeout;
	MSG msg;
	int ready = 0;
	int i;
	EmuCtr++;
	//DWORD needms = ms;
	if(EmuReseted && !rfu_enabled) //shouldn't be discared as it may need to be bridged/redirected
		for(i=1; i<=lanlink.numgbas; i++) DiscardData(i);
	c_s.Lock();
	EmuReseted = false;
	c_s.Unlock();
	DWORD starttm = GetTickCount();
	do { //Waiting for incomming data before continuing CPU execution
		//fdset.fd_count = lanlink.numgbas;
		notblock = 0; //0=blocking, 1=non-blocking
		for(i=1; i<=lanlink.numgbas; i++) {
			//fdset.fd_array[i-1] = tcpsocket[i];
			ioctlsocket(tcpsocket[i], FIONBIO, &notblock); //AdamN: temporarily use blocking for checking
			int ern=errno;
			if(ern!=0) {
				log("slIOCTL Error: %d\n",ern);
				//if(ern==10054 || ern==10053 || ern==10057 || ern==10051 || ern==10050 || ern==10065) lanlink.connected = false;
			}
			arg = 0; //1;
			if(connected[i])
			if(ioctlsocket(tcpsocket[i], FIONREAD, &arg)!=0) { //AdamN: Alternative(Faster) to Select(Slower), might gets 10038(invalid socket handle) error code when using non-blocking sockets
				int ern=errno; 
				if(ern!=0) {
					log("%sSC Error: %d\n",(LPCTSTR)LogStr,ern);
					char message[40];
					{c_s.Lock(); connected[i] = false; lanlink.connected = IsLinkConnected(); c_s.Unlock();}
					sprintf(message, _T("Client %d disconnected. (err: %d)"), i, ern);
					MessageBox(NULL, message, _T("Link"), MB_OK);
					break;
				}
			}
			if(arg>0) {ready++;break;}
		}
		//wsocktimeout.tv_sec = linktimeout / 1000;
		//wsocktimeout.tv_usec = linktimeout % 1000; //0; //AdamN: remainder should be set also isn't?
		//ready = select(0, &fdset, NULL, NULL, &wsocktimeout);
		//int ern=errno;
		//if(ern!=0) {
		//	log("slCC Error: %d\n",ern);
		//	if(ern==10054 || ern==10053 || ern==10057 || ern==10051 || ern==10050 || ern==10065) lanlink.connected = false;
		//}
		if(!ready && !AppTerminated) {
			SleepEx(1,true); //SleepEx(0,true); //to give time for incoming data
			if(PeekMessage(&msg, 0/*theApp.GetMainWnd()->m_hWnd*/,  0, 0, PM_NOREMOVE)) {
				if(msg.message==WM_CLOSE) {c_s.Lock(); AppTerminated=true; c_s.Unlock();} else theApp.PumpMessage(); //seems to be processing message only if it has message otherwise it halt the program
			}
		}
	} while (lanlink.connected && !ready && /*(int)*/(GetTickCount()-starttm)<(DWORD)ms && !AppTerminated && !EmuReseted); //with ms<0 might not gets a proper result?
	//if((GetTickCount()-starttm)>=(DWORD)ms) log("TimeOut:%d\n",ms);
	EmuCtr--;
	if(!ready) return(false); //return(0);
	return (i); //ready>0
}

int lserver::IsDataReady(void) {
	unsigned long arg;// = 0;
	unsigned long notblock = 1; //0=blocking, non-zero=non-blocking
	int ready = 0;
	int i;
	notblock = 0; //0=blocking, 1=non-blocking
	for(i=1; i<=lanlink.numgbas; i++) {
		if(EmuReseted && !rfu_enabled) DiscardData(i); //shouldn't be discared as it may need to be bridged/redirected
		ioctlsocket(tcpsocket[i], FIONBIO, &notblock); //AdamN: use non-blocking
		arg = 0;
		if(connected[i])
		if(ioctlsocket(tcpsocket[i], FIONREAD, &arg)!=0) { //AdamN: Alternative(Faster) to Select(Slower)
			int ern=errno; 
			if(ern!=0) {
				log("%sSC Error: %d\n",(LPCTSTR)LogStr,ern);
				char message[40];
				{c_s.Lock(); connected[i] = false; lanlink.connected = IsLinkConnected(); c_s.Unlock();}
				sprintf(message, _T("Client %d disconnected. (err: %d)"), i, ern);
				MessageBox(NULL, message, _T("Link"), MB_OK);
				break;
			}
		}
		if(arg>0) {ready++;break;}
	}
	c_s.Lock();
	EmuReseted = false;
	c_s.Unlock();
	if(ready==0) return(false);
	return(i); //arg>0
}

int lserver::DiscardData(int idx) { //empty received buffer
	if(idx && !tcpsocket[idx]) return 0;
	char buff[8192];
	unsigned long arg;
	int sz = 0;
	int a = 1, b = lanlink.numgbas;
	if(idx) {
		a = idx; b = idx;
	}
	for(int i=a; i<=b; i++) {
	arg = 0; //0=blocking, non-zero=non-blocking
	ioctlsocket(tcpsocket[i], FIONBIO, &arg); //AdamN: use non-blocking for checking
	do {
		arg = 0;
		if(connected[i])
		if(ioctlsocket(tcpsocket[i], FIONREAD, &arg)!=0) { //AdamN: Alternative(Faster) to Select(Slower)
			int ern=errno; 
			if(ern!=0) {
				log("%sCC Error: %d\n",(LPCTSTR)LogStr,ern);
				char message[40];
				{c_s.Lock(); connected[i] = false; lanlink.connected = IsLinkConnected(); c_s.Unlock();}
				sprintf(message, _T("Client %d disconnected. (err: %d)"), idx, ern);
				MessageBox(NULL, message, _T("Link"), MB_OK);
			}
		}
		if(arg>0) {
			int cnt=recv(tcpsocket[i], buff, min(arg,sizeof(buff)), 0);
			if(cnt>0) sz+=cnt;
		}
	} while (arg>0 && connected[i]);
	}
	return(sz);
}

// Client
lclient::lclient(void){
	intinbuffer = (int*)inbuffer;
	u16inbuffer = (u16*)inbuffer;
	u32inbuffer = (u32*)inbuffer;
	intoutbuffer = (int*)outbuffer;
	u16outbuffer = (u16*)outbuffer;
	u32outbuffer = (u32*)outbuffer;
	numtransfers = 0;
	oncesend = false;
	return;
}

int lclient::Init(LPHOSTENT hostentry, void *waitdlg){
	unsigned long notblock = 1; //0=blocking, non-zero=non-blocking
	DWORD nothing;
	
	serverinfo.sin_family = AF_INET;
	serverinfo.sin_port = htons(5738);
	serverinfo.sin_addr = *((LPIN_ADDR)*hostentry->h_addr_list);

	if(ioctlsocket(lanlink.tcpsocket, FIONBIO, &notblock)==SOCKET_ERROR) //use non-blocking mode
		return errno;
	
	if(lanlink.thread!=NULL){
		c_s.Lock(); //AdamN: Locking resource to prevent deadlock
		lanlink.terminate = true;
		c_s.Unlock(); //AdamN: Unlock it after use
		Sleep(linktimeout+100);
		//WaitForSingleObject(linksync[vbaid], 2000); //500
		lanlink.thread = NULL;
		//SetEvent(linksync[vbaid]); //should it be reset?
	}

	CloseLink(); //AdamN: close connections gracefully
	InitLink(); //AdamN: reinit sockets
	outsize = 0;
	insize = 0;

	//notblock = 0;
	//ioctlsocket(lanlink.tcpsocket, FIONBIO, &notblock); //AdamN: need to be in blocking mode? It seems Client Need to be in Blocking mode otherwise Select will generate error 10038, But Select on blocking socket will cause delays
	
	//((ServerWait*)waitdlg)->SetWindowText("Connecting..."); //AdamN: SetWindowText seems to cause problem on client connect
	((ServerWait*)waitdlg)->m_serveraddress.Format(_T("Connecting to %s"), inet_ntoa(*(LPIN_ADDR)hostentry->h_addr_list[0]));
	
	lanlink.terminate = false;
	
	lanlink.thread = CreateThread(NULL, 0, LinkClientThread, waitdlg, 0, &nothing);
	
	return 0;
}

DWORD WINAPI LinkClientThread(void *waitdlg){
	fd_set fdset;
	timeval wsocktimeout;
	int numbytes, cnt;
	char inbuffer[16];
	u16 *u16inbuffer = (u16*)inbuffer;

	unsigned long block = 0;
	BOOL shown = true;
	DWORD nothing;

	if(connect(lanlink.tcpsocket, (LPSOCKADDR)&lc.serverinfo, sizeof(SOCKADDR_IN))==SOCKET_ERROR){
		if(errno!=WSAEWOULDBLOCK){
			MessageBox(NULL, _T("Couldn't connect to server."), _T("Link"), MB_OK);
			return 1;
		}
		wsocktimeout.tv_sec = 1; //linktimeout / 1000; //1;
		wsocktimeout.tv_usec = 0; //linktimeout % 1000; //0;
		do{
			//WinHelper::CCriticalSection::CLock lock(&c_s);
			c_s.Lock(); //AdamN: Locking resource to prevent deadlock
			bool canceled=lanlink.terminate; //AdamN: w/o locking might not be thread-safe
			c_s.Unlock(); //AdamN: Unlock it after use
			if(canceled) return 0;
			fdset.fd_count = 1;
			fdset.fd_array[0] = lanlink.tcpsocket;
			shown = IsWindow(((ServerWait*)waitdlg)->GetSafeHwnd()/*m_hWnd*/); //AdamN: trying to detect when Cancel button pressed (which cause Waiting for Player window to be closed)
			if(shown)
				((ServerWait*)waitdlg)->m_prgctrl.StepIt();
		} while(select(0, NULL, &fdset, NULL, &wsocktimeout)!=1/*&&connect(lanlink.tcpsocket, (LPSOCKADDR)&lc.serverinfo, sizeof(SOCKADDR_IN))!=0*/);
	}

	ioctlsocket(lanlink.tcpsocket, FIONBIO, &block); //AdamN: temporary using blocking mode

	numbytes = 0;
	inbuffer[0] = 1;
	DWORD lat = GetTickCount();
	while(numbytes<inbuffer[0]/*4*/) {
		cnt = recv(lanlink.tcpsocket, inbuffer+numbytes, inbuffer[0]-numbytes/*16*/, 0); //AdamN: receiving index and #of gbas
		if((cnt<=0/*SOCKET_ERROR*/)||(errno!=0)) break; //AdamN: to prevent stop responding due to infinite loop on socket error
		numbytes += cnt;
		//if(IsWindow(((ServerWait*)waitdlg)->GetSafeHwnd()/*m_hWnd*/))
		//	((ServerWait*)waitdlg)->m_prgctrl.StepIt(); //AdamN: update progressbar so it won't look stucked
	}
	lat = GetTickCount() - lat;
	linkid = inbuffer[1];
	lanlink.numgbas = u16inbuffer[1];
	vbaid = linkid;

	if(waitdlg && IsWindow(((ServerWait*)waitdlg)->GetSafeHwnd()/*m_hWnd*/)) { //AdamN: not really useful for UpdateData
		((ServerWait*)waitdlg)->m_serveraddress.Format(_T("Connected as Client #%d  (Latency: %dms)"), linkid, lat);
		if(lanlink.numgbas!=linkid)	((ServerWait*)waitdlg)->m_plconn[0].Format(_T("Waiting for %d more players to join"), lanlink.numgbas-linkid);
		else ((ServerWait*)waitdlg)->m_plconn[0].Format(_T("All players joined."));
		CWnd *tmpwnd = NULL;
		//((ServerWait*)waitdlg)->UpdateData(false); //AdamN: refreshing static text after being modified above, may not be thread-safe (causing assertion failed)
		tmpwnd = ((ServerWait*)waitdlg)->GetDlgItem(IDC_STATIC1);
		if(tmpwnd && IsWindow(tmpwnd->GetSafeHwnd()/*m_hWnd*/)) tmpwnd->SetWindowText((LPCTSTR)((ServerWait*)waitdlg)->m_serveraddress); //((ServerWait*)waitdlg)->Invalidate(); //((ServerWait*)waitdlg)->SendMessage(WM_PAINT, 0, 0); //AdamN: using message might be safer than UpdateData but might not works
		tmpwnd = ((ServerWait*)waitdlg)->GetDlgItem(IDC_STATIC2);
		if(tmpwnd && IsWindow(tmpwnd->GetSafeHwnd()/*m_hWnd*/)) tmpwnd->SetWindowText((LPCTSTR)((ServerWait*)waitdlg)->m_plconn[0]); //m_plconn[0]
		//((ServerWait*)waitdlg)->GetDlgItem(IDC_SERVERWAIT)->Invalidate(); //m_prgctrl
		((ServerWait*)waitdlg)->Invalidate();
	}

	//MessageBox(NULL, _T("Connected."), _T("Link"), MB_OK); //AdamN: shown when the game initialize multiplayer mode (on VBALink it's shown after players connected to server), is it really needed to show this thing?

	numbytes = 0;
	inbuffer[0] = 1;
	while(numbytes<inbuffer[0]) { //AdamN: loops until all players connected or is it until the game initialize multiplayer mode?, progressbar should be updated tho
		cnt = recv(lanlink.tcpsocket, inbuffer+numbytes, /*16*/inbuffer[0]-numbytes, 0);
		if(cnt==SOCKET_ERROR) break; //AdamN: to prevent stop responding due to infinite loop on socket error
		numbytes += cnt;
		if(waitdlg && IsWindow(((ServerWait*)waitdlg)->GetSafeHwnd()/*m_hWnd*/))
			((ServerWait*)waitdlg)->m_prgctrl.StepIt(); //AdamN: update progressbar so it won't look stucked
	}
	if(waitdlg && IsWindow(((ServerWait*)waitdlg)->GetSafeHwnd()/*m_hWnd*/))
		((ServerWait*)waitdlg)->SendMessage(WM_CLOSE, 0, 0); //AdamN: may cause assertion failed when window no longer existed

	/*block = 1; //AdamN: 1=non-blocking
	ioctlsocket(lanlink.tcpsocket, FIONBIO, &block); //AdamN: back to non-blocking mode?*/

	//lanlink.connected = true;

	//SetEvent(linksync[vbaid]); //AdamN: saying the lanlink.thread is exiting? might cause thread to stuck when app exited

	c_s.Lock();
	lanlink.connected = true;
	if(lanlink.connected) {
		lanlink.terminate = false;
		lanlink.thread = CreateThread(NULL, 0, LinkHandlerThread, NULL, 0, &nothing); //AdamN: trying to reduce the lag by handling sockets in a different thread, not working properly yet
	}
	c_s.Unlock();

	return 0;
}

void lclient::CheckConn(void){ //AdamN: used on Idle to fill in buffer, needed for Client to works properly
	//return;
	unsigned long arg = 0; 
	BOOL recvd = false;
	BOOL disable = true;
	
	unsigned long notblock = 0; //0=blocking, non-zero=non-blocking
	ioctlsocket(lanlink.tcpsocket, FIONBIO, &notblock); //AdamN: use blocking for receiving

	/*fd_set fdset;
	timeval wsocktimeout;
	fdset.fd_count = 1;
	fdset.fd_array[0] = lanlink.tcpsocket;
	wsocktimeout.tv_sec = linktimeout / 1000;
	wsocktimeout.tv_usec = linktimeout % 1000; //0; //AdamN: remainder should be set also isn't?
	if(select(0, &fdset, NULL, NULL, &wsocktimeout)<=0){ //AdamN: may cause noticible delay, result can also be SOCKET_ERROR
		//numtransfers = 0;
		int ern=errno; //AdamN: select seems to get ern=10038(invalid socket handle) when used on non-blocking socket
		if(ern!=0)
		log("%sCC0[%d]\n",(LPCTSTR)LogStr,ern);
		return;
	} else*/
	arg = 0;
	if(ioctlsocket(lanlink.tcpsocket, FIONREAD, &arg)!=0) { //AdamN: Alternative(Faster) to Select(Slower)
		int ern=errno; 
		if(ern!=0) {
			log("%sCC0[%d]\n",(LPCTSTR)LogStr,ern);
			LinkConnected(false); //{c_s.Lock(); lanlink.connected = false; c_s.Unlock();}
			char message[40];
			sprintf(message, _T("Server disconnected improperly. (err: %d)"), ern);
			MessageBox(NULL, message, _T("Link"), MB_OK);
		}
		return;
	}

	notblock = 0; //0=blocking, non-zero=non-blocking
	ioctlsocket(lanlink.tcpsocket, FIONBIO, &notblock); //AdamN: use non-blocking for receiving

	//numbytes = 0;

	if(arg>0)
	if((numbytes=recv(lanlink.tcpsocket, inbuffer, /*256*//*arg*/2, /*0*/MSG_PEEK))>0){ //>=0 //AdamN: this socket need to be in non-blocking mode otherwise it will wait forever until server's game entering multiplayer mode
		/*#ifdef GBA_LOGGING
			if(systemVerbose & VERBOSE_LINK) {
				log("%sCC1\n",(LPCTSTR)LogStr);
				log("CCrecv Size : %d  %s\n", numbytes, (LPCTSTR)DataHex(inbuffer,numbytes));
			}
		#endif*/
		
		if(numbytes>1 && ((inbuffer[1] & 0xc0)==0x80/*'W' || (GetSIOMode(READ16LE(&ioMem[COMM_SIOCNT]), READ16LE(&ioMem[COMM_RCNT]))!=MULTIPLAYER)*/)) numbytes = 0; //don't handle wireless packets

		if(numbytes>1) { //AdamN: otherwise socket error
		numbytes = 0;
		int cnt = 0;
		while(numbytes<inbuffer[0]) {
			cnt=recv(lanlink.tcpsocket, inbuffer+numbytes, /*256*/inbuffer[0]-numbytes, 0);
			if(cnt<=0) break; //==SOCKET_ERROR //AdamN: to prevent stop responding due to infinite loop on socket error
			numbytes += cnt;
			/*#ifdef GBA_LOGGING
				if(systemVerbose & VERBOSE_LINK) {
					log("%sCC2\n",(LPCTSTR)LogStr);
					log("CCrecv Size : %d  %s\n", cnt, (LPCTSTR)DataHex(inbuffer,cnt));
				}
			#endif*/
		}
		#ifdef GBA_LOGGING
				if(systemVerbose & VERBOSE_LINK) {
					log("%sCC2\n",(LPCTSTR)LogStr);
					log("CCrecv Size : %d  %s\n", cnt, (LPCTSTR)DataHex(inbuffer/*+numbytes*/,cnt));
				}
		#endif
		}
		recvd = (numbytes>1);
		if(numbytes>1)
		if(inbuffer[1]==-32){ //AdamN: only true if server was closed gracefully
			outbuffer[0] = 4;
			notblock = 1; //0=blocking, non-zero=non-blocking
			ioctlsocket(lanlink.tcpsocket, FIONBIO, &notblock); //AdamN: use non-blocking for sending since server might not connected anymore
			//setsockopt(lanlink.tcpsocket, IPPROTO_TCP, TCP_NODELAY, (char*)&disable, sizeof(BOOL)); //true=send packet immediately
			#ifdef GBA_LOGGING
				if(systemVerbose & VERBOSE_LINK) {
					log("%sCC3\n",(LPCTSTR)LogStr);
					log("CCsend Size : %d  %s\n", 4, (LPCTSTR)DataHex(outbuffer,4));
				}
			#endif
			send(lanlink.tcpsocket, outbuffer, 4, 0); //try to send to check whether it's no longer connected
			LinkConnected(false); //{c_s.Lock(); lanlink.connected = false; c_s.Unlock();}
			DiscardData();
			MessageBox(NULL, _T("Server disconnected gracefully."), _T("Link"), MB_OK);
			return;
		}
		
		/*if(GetSIOMode(READ16LE(&ioMem[COMM_SIOCNT]), READ16LE(&ioMem[COMM_RCNT]))!=MULTIPLAYER) { //received data (other than disconneting code) may need to be discarded when not in multiplayer mode? (to prevent from replying with another data)
			recvd = false;
		}*/

		if(recvd) { //buffer format: u8Size,u8Speed,u16Data0,intTime,u16Data1/2,u16Data3/2
		int ndata = (inbuffer[0]-6)/2; //number of received client data (3 data on 4 players)
		numtransfers = 1;
		savedlinktime = 0;
		linkdata[0] = u16inbuffer[1];
		tspeed = inbuffer[1] & 3;
		for(i=1, numbytes=4; i<=lanlink.numgbas; i++)
			if(i!=linkid && i<=ndata) linkdata[i] = u16inbuffer[numbytes++]; //linkid = vbaid ?
		after = false;
		oncewait = true;
		oncesend = true;
		}
	}
	return;
}

BOOL lclient::Recv(void){
	//return false;
	BOOL recvd = false;
	BOOL disable = true;
	unsigned long arg = 0;

	unsigned long notblock = 0; //0=blocking, non-zero=non-blocking
	ioctlsocket(lanlink.tcpsocket, FIONBIO, &notblock); //AdamN: use non-blocking for checking

	fdset.fd_count = 1;
	fdset.fd_array[0] = lanlink.tcpsocket;
	wsocktimeout.tv_sec = linktimeout / 1000;
	wsocktimeout.tv_usec = linktimeout % 1000; //0; //AdamN: remainder should be set also isn't?
	
	/*arg = 0;
	if(ioctlsocket(lanlink.tcpsocket, FIONREAD, &arg)!=0) { //Faster alternative than Select but doesn't seems to works as good as Select
		int ern=errno; //AdamN: this seems to get ern=10038(invalid socket handle) often
		numtransfers = 0;
		if(ern!=0)
		log("%sCC0[%d]\n",(LPCTSTR)LogStr,ern);
		return recvd;
	}
	if(arg<=0) return recvd;*/
	
	if(select(0, &fdset, NULL, NULL, &wsocktimeout)<=0){ //AdamN: may cause noticible delay, result can also be SOCKET_ERROR, Select seems to be needed to maintain stability
		numtransfers = 0;
		int ern=errno; //may gets error 10038(invalid socket handle) when using non-blocking sockets
		if(ern!=0)
		log("%sCR1[%d]\n",(LPCTSTR)LogStr,ern);
		return recvd;
	}
	
	notblock = 1; //0=blocking, non-zero=non-blocking
	ioctlsocket(lanlink.tcpsocket, FIONBIO, &notblock); //AdamN: use blocking for receiving
	numbytes = 0;
	inbuffer[0] = 1; 
	while(numbytes<inbuffer[0]){
		int cnt=recv(lanlink.tcpsocket, inbuffer+numbytes, /*256*/inbuffer[0]-numbytes, 0);
		if(cnt<=0) break; //==SOCKET_ERROR //AdamN: to prevent stop responding due to infinite loop on socket error
		numbytes += cnt;
		/*#ifdef GBA_LOGGING
			if(systemVerbose & VERBOSE_LINK) {
				log("%sCR2\n",(LPCTSTR)LogStr);
				log("CRecv Size : %d  %s\n", cnt, (LPCTSTR)DataHex(inbuffer,cnt));
			}
		#endif*/
	}
	#ifdef GBA_LOGGING
			if(systemVerbose & VERBOSE_LINK) {
				log("%sCR2\n",(LPCTSTR)LogStr);
				log("CRecv Size : %d  %s\n", numbytes, (LPCTSTR)DataHex(inbuffer,numbytes));
			}
	#endif
	recvd=(errno==0);
	if(inbuffer[1]==-32){ //AdamN: only true if server was closed gracefully
		outbuffer[0] = 4;
		outbuffer[1] = -32; //is this needed?
		notblock = 1; //0=blocking, non-zero=non-blocking
		ioctlsocket(lanlink.tcpsocket, FIONBIO, &notblock); //AdamN: use non-blocking for sending since the otherside might no longer connected
		//setsockopt(lanlink.tcpsocket, IPPROTO_TCP, TCP_NODELAY, (char*)&disable, sizeof(BOOL)); //true=send packet immediately
		#ifdef GBA_LOGGING
			if(systemVerbose & VERBOSE_LINK) {
				log("%sCR3\n",(LPCTSTR)LogStr);
				log("Csend Size : %d  %s\n", 4, (LPCTSTR)DataHex(outbuffer,4));
			}
		#endif
		send(lanlink.tcpsocket, outbuffer, 4, 0);
		LinkConnected(false); //{c_s.Lock(); lanlink.connected = false; c_s.Unlock();}
		MessageBox(NULL, _T("Server disconnected gracefully."), _T("Link"), MB_OK);
		//recvd=(errno==0);
		return recvd;
	}
	if(recvd) {
	tspeed = inbuffer[1] & 3;
	linkdata[0] = u16inbuffer[1];
	savedlinktime = intinbuffer[1];
	for(i=1, numbytes=4; i<=lanlink.numgbas; i++)
		if(i!=linkid) linkdata[i] = u16inbuffer[numbytes++]; //linkid = vbaid ?
	numtransfers++;
	if(numtransfers==0) numtransfers = 2;
	after = false;
	}
	return recvd;
}

BOOL lclient::Send(void){
	//return false;
	BOOL sent = false;
	BOOL disable = true;
	outbuffer[0] = 4;
	outbuffer[1] = linkid<<2;
	u16outbuffer[1] = linkdata[linkid];
	unsigned long notblock = 0; //0=blocking, non-zero=non-blocking
	ioctlsocket(lanlink.tcpsocket, FIONBIO, &notblock); //AdamN: use blocking for sending to prevent partially sent data
	//setsockopt(lanlink.tcpsocket, IPPROTO_TCP, TCP_NODELAY, (char*)&disable, sizeof(BOOL)); //true=send packet immediately
	#ifdef GBA_LOGGING
		if(systemVerbose & VERBOSE_LINK) {
			log("%sCS1\n",(LPCTSTR)LogStr);
			log("CSend Size : %d  %s\n", 4, (LPCTSTR)DataHex(outbuffer,4));
		}
	#endif
	sent=(send(lanlink.tcpsocket, outbuffer, 4, 0)>=0);
	int ern=errno;
	if(ern!=0 && ern!=lastern) {
		if(ern!=10035 && ern!=10060) {LinkConnected(false);} //{c_s.Lock(); lanlink.connected = false; c_s.Unlock();}
		log("WSAError = %d [%d]\n",ern,lastern); 
		lastern = ern;
	}
	return sent;
}

BOOL lclient::SendData(int size, int nretry){
	//return false;
	int sent = 0;
	BOOL disable = true; //true=send packet immediately
	unsigned long notblock = 0; //1; //0=blocking, non-zero=non-blocking
	ioctlsocket(lanlink.tcpsocket, FIONBIO, &notblock); //AdamN: use non-blocking for sending to prevent getting timeout when socket's buffer is full
	//setsockopt(lanlink.tcpsocket, IPPROTO_TCP, TCP_NODELAY, (char*)&disable, sizeof(BOOL)); //true=send packet immediately
	#ifdef GBA_LOGGING
		if(systemVerbose & VERBOSE_LINK) {
			//log("%sCS01\n",(LPCTSTR)LogStr);
			log("%sCSend00 Size : %d  %s\n", (LPCTSTR)LogStr, size, (LPCTSTR)DataHex(outbuffer,size));
		}
	#endif
	int ern = 0, lastern = 0;
	int i = nretry; //+1;
	int sz = size;
	while (sz>0 && lanlink.connected && i>=0) {
	do {
		DWORD lat = GetTickCount();
		sent=send(lanlink.tcpsocket, outbuffer+(size-sz), sz, 0);
		lanlink.latency = GetTickCount() - lat;
		ern = errno;
		if(ern!=0) {
			if(ern!=10035 && ern!=10060) {
				if(i<=0) LinkConnected(false); //{c_s.Lock(); lanlink.connected = false; c_s.Unlock();}
			}
			if(ern!=lastern) 
			log("%sCS Error: %d [%d] (%d/%d)  %d\n",(LPCTSTR)LogStr,ern,lastern,sz,size,GetTickCount());
			lastern = ern;
		}
		if(!lanlink.connected) MessageBox(NULL, _T("Server Disconnected."), _T("Link"), MB_OK);
		i--;
	} while (i>=0 && lanlink.connected && ern);
	if(sent>0) sz -= sent;
	}
	return (!ern); //sent;
}

BOOL lclient::SendData(const char *buf, int size, int nretry){
	//return false;
	int sent = 0;
	BOOL disable = true; //true=send packet immediately
	unsigned long notblock = 0; //1; //0=blocking, non-zero=non-blocking
	ioctlsocket(lanlink.tcpsocket, FIONBIO, &notblock); //AdamN: use non-blocking for sending to prevent getting timeout when socket's buffer is full
	//setsockopt(lanlink.tcpsocket, IPPROTO_TCP, TCP_NODELAY, (char*)&disable, sizeof(BOOL)); //true=send packet immediately
	#ifdef GBA_LOGGING
		if(systemVerbose & VERBOSE_LINK) {
			//log("%sCS01\n",(LPCTSTR)LogStr);
			log("%sCSend00 Size : %d  %s\n", (LPCTSTR)LogStr, size, (LPCTSTR)DataHex(buf,size));
		}
	#endif
	int ern = 0, lastern = 0;
	int i = nretry; //+1;
	int sz = size;
	while (sz>0 && lanlink.connected && i>=0) {
	do {
		DWORD lat = GetTickCount();
		sent=send(lanlink.tcpsocket, buf+(size-sz), sz, 0);
		lanlink.latency = GetTickCount() - lat;
		ern = errno;
		if(ern!=0) {
			if(ern!=10035 && ern!=10060) {
				if(i<=0) LinkConnected(false); //{c_s.Lock(); lanlink.connected = false; c_s.Unlock();}
			}
			if(ern!=lastern) 
			log("%sCS Error: %d [%d] (%d/%d)  %d\n",(LPCTSTR)LogStr,ern,lastern,sz,size,GetTickCount());
			lastern = ern;
		}
		if(!lanlink.connected) MessageBox(NULL, _T("Server Disconnected."), _T("Link"), MB_OK);
		i--;
	} while (i>=0 && lanlink.connected && ern);
	if(sent>0) sz -= sent;
	}
	return (!ern); //sent;
}

BOOL lclient::RecvData(int size, bool peek){
	//return false;
	BOOL recvd = false;
	BOOL disable = true;
	unsigned long notblock = 0; //0=blocking, non-zero=non-blocking
	ioctlsocket(lanlink.tcpsocket, FIONBIO, &notblock); //AdamN: use blocking for receiving
	setsockopt(lanlink.tcpsocket, IPPROTO_TCP, TCP_NODELAY, (char*)&disable, sizeof(BOOL)); //true=send packet immediately
	int flg = 0;
	if(peek) flg = MSG_PEEK;
	int rsz = size;
	do {
		int cnt=recv(lanlink.tcpsocket, inbuffer+(size-rsz), rsz, flg);
		if(cnt>=0) rsz-=cnt; else LinkConnected(false); //{c_s.Lock(); lanlink.connected = false; c_s.Unlock();}
		int ern = errno;
		if(ern!=0) {
			if(ern!=lastern) {
				log("WSAError: %d %d\n", ern, lastern);
				lastern = ern;
			}
			LinkConnected(false); //{c_s.Lock(); lanlink.connected = false; c_s.Unlock();}
		}
		if(!lanlink.connected) {
			char message[40];
			sprintf(message, _T("Server disconnected. (err: %d)"), ern);
			MessageBox(NULL, message, _T("Link"), MB_OK);
		}
	} while (rsz>0 && lanlink.connected);
	insize = size-rsz;
	recvd = (rsz<=0);
	#ifdef GBA_LOGGING
		if(systemVerbose & VERBOSE_LINK) {
			//log("%sCR01\n",(LPCTSTR)LogStr);
			log("%sCRecv(%d) Size : %d/%d  %s\n", (LPCTSTR)LogStr, peek, insize, size, (LPCTSTR)DataHex(inbuffer,size));
		}
	#endif
	return recvd;
}

BOOL lclient::WaitForData(int ms) {
	unsigned long notblock = 1; //AdamN: 0=blocking, non-zero=non-blocking
	unsigned long arg = 0;
	//fd_set fdset;
	//timeval wsocktimeout;
	MSG msg;
	int ready = 0;
	//DWORD needms = ms;
	EmuCtr++;
	if(EmuReseted) DiscardData();
	c_s.Lock();
	EmuReseted = false;
	c_s.Unlock();
	DWORD starttm = GetTickCount();
	do { //Waiting for incomming data before continuing CPU execution		
		//fdset.fd_count = 1;
		notblock = 0;
		//fdset.fd_array[0] = lanlink.tcpsocket;
		ioctlsocket(lanlink.tcpsocket, FIONBIO, &notblock); //AdamN: temporarily use blocking for checking
		int ern=errno;
		if(ern!=0) {
			log("clIOCTL Error: %d\n",ern);
			//if(ern==10054 || ern==10053 || ern==10057 || ern==10051 || ern==10050 || ern==10065) lanlink.connected = false;
		}
		arg = 0; //1;
		if(ioctlsocket(lanlink.tcpsocket, FIONREAD, &arg)!=0) { //AdamN: Alternative(Faster) to Select(Slower), might gets 10038(invalid socket handle) error code when using non-blocking sockets
			int ern=errno; 
			if(ern!=0) {
				log("%sCC Error: %d\n",(LPCTSTR)LogStr,ern);
				LinkConnected(false); //{c_s.Lock(); lanlink.connected = false; c_s.Unlock();}
				char message[40];
				sprintf(message, _T("Server disconnected. (err: %d)"), ern);
				MessageBox(NULL, message, _T("Link"), MB_OK);
				break;
			}
		}
		if(arg>0) ready++;
		//wsocktimeout.tv_sec = linktimeout / 1000;
		//wsocktimeout.tv_usec = linktimeout % 1000; //0; //AdamN: remainder should be set also isn't?
		//ready = select(0, &fdset, NULL, NULL, &wsocktimeout);
		//int ern=errno;
		//if(ern!=0) {
		//	log("slCC Error: %d\n",ern);
		//	if(ern==10054 || ern==10053 || ern==10057 || ern==10051 || ern==10050 || ern==10065) lanlink.connected = false;
		//}
		if(!ready && !AppTerminated) {
			SleepEx(1,true); //SleepEx(0,true); //to give time for incoming data
			if(PeekMessage(&msg, 0/*theApp.GetMainWnd()->m_hWnd*/,  0, 0, PM_NOREMOVE)) {
				if(msg.message==WM_CLOSE) {c_s.Lock(); AppTerminated=true; c_s.Unlock();} else theApp.PumpMessage(); //seems to be processing message only if it has message otherwise it halt the program
			}
		}
	} while (lanlink.connected && !ready && /*(int)*/(GetTickCount()-starttm)<(DWORD)ms && !AppTerminated && !EmuReseted); //with ms<0 might not gets a proper result?
	//if((GetTickCount()-starttm)>=(DWORD)ms) log("TimeOut:%d\n",ms);
	EmuCtr--;
	return (ready>0);
}

BOOL lclient::IsDataReady(void) {
	unsigned long arg;
	if(EmuReseted) DiscardData();
	c_s.Lock();
	EmuReseted = false;
	c_s.Unlock();
	arg = 0; //0=blocking, non-zero=non-blocking
	ioctlsocket(lanlink.tcpsocket, FIONBIO, &arg); //AdamN: use non-blocking
	arg = 0;
	if(ioctlsocket(lanlink.tcpsocket, FIONREAD, &arg)!=0) { //AdamN: Alternative(Faster) to Select(Slower)
		int ern=errno; 
		if(ern!=0) {
			log("%sCC Error: %d\n",(LPCTSTR)LogStr,ern);
			LinkConnected(false); //{c_s.Lock(); lanlink.connected = false; c_s.Unlock();}
			char message[40];
			sprintf(message, _T("Server disconnected. (err: %d)"), ern);
			MessageBox(NULL, message, _T("Link"), MB_OK);
		}
	}
	return(arg>0);
}

int lclient::DiscardData(void) { //empty received buffer
	char buff[8192];
	unsigned long arg;
	int sz = 0;
	arg = 0; //0=blocking, non-zero=non-blocking
	ioctlsocket(lanlink.tcpsocket, FIONBIO, &arg); //AdamN: use non-blocking for checking
	do {
		arg = 0;
		if(ioctlsocket(lanlink.tcpsocket, FIONREAD, &arg)!=0) { //AdamN: Alternative(Faster) to Select(Slower)
			int ern=errno; 
			if(ern!=0) {
				log("%sCC Error: %d\n",(LPCTSTR)LogStr,ern);
				LinkConnected(false); //{c_s.Lock(); lanlink.connected = false; c_s.Unlock();}
				char message[40];
				sprintf(message, _T("Server disconnected. (err: %d)"), ern);
				MessageBox(NULL, message, _T("Link"), MB_OK);
			}
		}
		if(arg>0) {
			int cnt=recv(lanlink.tcpsocket, buff, min(arg,sizeof(buff)), 0);
			if(cnt>0) sz+=cnt;
		}
	} while (arg>0 && lanlink.connected);
	return(sz);
}

BOOL LinkSendData(char *buf, int size, int nretry, int idx) {
	BOOL sent = false;
	c_s.Lock();
	if(linkid) //client
		sent = lc.SendData(buf, size, nretry);
	else //server
		sent = ls.SendData(buf, size, nretry, idx);
	c_s.Unlock();
	return(sent);
}

BOOL LinkRecvData(char *buf, int size, int idx, bool peek) {
	BOOL recvd = false;
	c_s.Lock();
	if(linkid) { //client
		recvd = lc.RecvData(size, peek);
		if(recvd) memcpy(buf, lc.inbuffer, size);
	} else { //server
		recvd = ls.RecvData(size, idx, peek);
		if(recvd) memcpy(buf, ls.inbuffer, size);
	}
	c_s.Unlock();
	return(recvd);
}

BOOL LinkIsDataReady(int *idx) {
	int rdy = false;
	c_s.Lock();
	if(linkid) { //client
		rdy = lc.IsDataReady();
		if(idx)
		*idx = 0;
	} else { //server
		rdy = ls.IsDataReady();
		if(idx)
		*idx = rdy;
	}
	c_s.Unlock();
	return(rdy);
}

BOOL LinkWaitForData(int ms, int *idx) {
	int rdy = false;
	c_s.Lock();
	if(linkid) { //client
		rdy = lc.WaitForData(ms);
		if(idx)
		*idx = 0;
	} else { //server
		rdy = ls.WaitForData(ms);
		if(idx)
		*idx = rdy;
	}
	c_s.Unlock();
	return(rdy);
}

int LinkDiscardData(int idx) {
	int rdy = false;
	c_s.Lock();
	if(linkid) { //client
		rdy = lc.DiscardData();
	} else { //server
		rdy = ls.DiscardData(idx);
	}
	c_s.Unlock();
	return(rdy);
}

int LinkGetBufferSize(int opt) { //SO_SNDBUF or SO_RCVBUF
	int optVal = 8192; //32767; //linkbuffersize;
	int optLen = sizeof(int);
	getsockopt(lanlink.tcpsocket, SOL_SOCKET, opt, (char*)&optVal, &optLen);
	return optVal;
}

BOOL LinkCanSend(int size) { //AdamN: since Windows doesn't support FIONWRITE or SIOCOUTQ we use an alternative approach to check send buffer availability
	int optVal;
	int optLen = sizeof(int);
	bool ok = false;
	if(getsockopt(lanlink.tcpsocket, SOL_SOCKET, SO_SNDLOWAT, (char*)&optVal, &optLen)!=SOCKET_ERROR) {
		int oldVal = optVal;
		optVal = size;
		if(setsockopt(lanlink.tcpsocket, SOL_SOCKET, SO_SNDLOWAT, (char*)&optVal, optLen)!=SOCKET_ERROR) {
			unsigned long notblock = 1; //0; //0=blocking, non-zero=non-blocking
			ioctlsocket(lanlink.tcpsocket, FIONBIO, &notblock); //AdamN: use blocking for checking

			fd_set fdset;
			timeval wsocktimeout;
			fdset.fd_count = 1;
			fdset.fd_array[0] = lanlink.tcpsocket;
			wsocktimeout.tv_sec = linktimeout / 1000;
			wsocktimeout.tv_usec = linktimeout % 1000; //0; //AdamN: remainder should be set also isn't?
			if(select(0, NULL, &fdset, NULL, &wsocktimeout)<=0){ //AdamN: may cause noticible delay, result can also be SOCKET_ERROR
				/*int ern=errno; //AdamN: select seems to get ern=10038(invalid socket handle) when used on non-blocking socket
				if(ern!=0)
				log("%sCS[%d]\n",(LPCTSTR)LogStr,ern);*/
			} else ok = true;

			optVal = oldVal;
			setsockopt(lanlink.tcpsocket, SOL_SOCKET, SO_SNDLOWAT, (char*)&optVal, optLen);
		}
	}
	return ok;
}

// Uncalled
void LinkSStop(void){
	if(!oncewait){
		if(linkid){
			if(lanlink.numgbas==1) return;
			lc.Recv();
		}
		else ls.Recv();

		oncewait = true;
		UPDATE_REG(COMM_SIODATA32_H, linkdata[1]);
		UPDATE_REG(0x124, linkdata[2]);
		UPDATE_REG(0x126, linkdata[3]);
	}
	return;
}

// ??? Called when COMM_SIODATA8 written
void LinkSSend(u16 value){
	if(linkid&&!lc.oncesend){
		linkdata[linkid] = value;
		lc.Send();
		lc.oncesend = true;
	}
}

#endif // _MSC_VER

#else // NO_LINK
//void JoyBusUpdate(int ticks) {}
#endif // NO_LINK
