//iphone.mm

namespace Base
{
    
    void nsLog(const char* str)
    {
        NSLog(@"%s", str);
    }
    
    void nsLogv(const char* format, va_list arg)
    {
        auto formatStr = [[NSString alloc] initWithBytesNoCopy:(void*)format length:strlen(format) encoding:NSUTF8StringEncoding freeWhenDone:YES];
        NSLogv(formatStr, arg);
    }
}