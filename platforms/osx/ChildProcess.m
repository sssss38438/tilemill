
#import "ChildProcess.h"

@implementation ChildProcess

- (id)initWithController:(id <ChildProcessController>)cont arguments:(NSArray *)args
{
    self = [super init];
    controller = cont;
    arguments = [args retain];
    launched = NO;
    return self;
}

- (void)dealloc
{
    [self stopProcess];
    [arguments release];
    [task release];
    [super dealloc];
}

- (void) startProcess
{
    [controller processStarted];
    task = [[NSTask alloc] init];
    [task setStandardOutput: [NSPipe pipe]];
    [task setStandardError: [task standardOutput]];
    [task setCurrentDirectoryPath: [arguments objectAtIndex:0]];
    [task setLaunchPath: [arguments objectAtIndex:1]];
    [[NSNotificationCenter defaultCenter] addObserver:self 
        selector:@selector(getData:) 
        name: NSFileHandleReadCompletionNotification 
        object: [[task standardOutput] fileHandleForReading]];
    [[[task standardOutput] fileHandleForReading] readInBackgroundAndNotify];
    [task launch];    
}

- (void) stopProcess
{
    NSData *data;
    [[NSNotificationCenter defaultCenter] removeObserver:self name:NSFileHandleReadCompletionNotification object: [[task standardOutput] fileHandleForReading]];
    [task terminate];

    while ((data = [[[task standardOutput] fileHandleForReading] availableData]) && [data length])
    {
        [controller appendOutput: [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease]];
    }

    [controller processFinished];
    controller = nil;
}

- (void) getData: (NSNotification *)aNotification
{
    NSData *data = [[aNotification userInfo] objectForKey:NSFileHandleNotificationDataItem];
    if ([data length])
    {
        NSString *message = [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease];
        [controller appendOutput: message];
        if ([message hasPrefix:@"Started"] && !launched) {
            launched = YES;
            [controller firstData];
        }
    } else {
        [self stopProcess];
    }
    
    [[aNotification object] readInBackgroundAndNotify];  
}

@end
