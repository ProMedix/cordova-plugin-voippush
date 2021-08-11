/*
 Licensed to the Apache Software Foundation (ASF) under one
 or more contributor license agreements.  See the NOTICE file
 distributed with this work for additional information
 regarding copyright ownership.  The ASF licenses this file
 to you under the Apache License, Version 2.0 (the
 "License"); you may not use this file except in compliance
 with the License.  You may obtain a copy of the License at

 http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing,
 software distributed under the License is distributed on an
 "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
 KIND, either express or implied.  See the License for the
 specific language governing permissions and limitations
 under the License.
 */

#import "CDVVoipPush.h"
#import <PushKit/PushKit.h>

@implementation CDVVoipPush

@synthesize callbackId;

- (void)voipRegistration:(CDVInvokedUrlCommand*)command {
    [self.commandDelegate runInBackground:^ {
        dispatch_queue_t mainQueue = dispatch_get_main_queue();
        // Create a push registry object
        PKPushRegistry * voipRegistry = [[PKPushRegistry alloc] initWithQueue: mainQueue];
        // Set the registry's delegate to self
        voipRegistry.delegate = self;
        // Set the push type to VoIP
        voipRegistry.desiredPushTypes = [NSSet setWithObject:PKPushTypeVoIP];

        self.callbackId = command.callbackId;

        // if push token available call the token callback
        NSData *tokenData = [voipRegistry pushTokenForType:PKPushTypeVoIP];
        if (tokenData != nil) {
            if ([tokenData length] != 32) {
                NSLog(@"Incorrect push token length: %lu", (unsigned long)tokenData.length);
                return;
            }
            
            // https://stackoverflow.com/questions/9372815/how-can-i-convert-my-device-token-nsdata-into-an-nsstring/9372848#9372848
            const unsigned *tokenBytes = [tokenData bytes];
            NSString *token = [NSString stringWithFormat:@"%08x%08x%08x%08x%08x%08x%08x%08x",
                                ntohl(tokenBytes[0]), ntohl(tokenBytes[1]), ntohl(tokenBytes[2]),
                                ntohl(tokenBytes[3]), ntohl(tokenBytes[4]), ntohl(tokenBytes[5]),
                                ntohl(tokenBytes[6]), ntohl(tokenBytes[7])];
            
            NSMutableDictionary* pushMessage = [NSMutableDictionary dictionaryWithCapacity:2];
            [pushMessage setObject:token forKey:@"token"];
            [pushMessage setObject:PKPushTypeVoIP forKey:@"type"];

            CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:pushMessage];
            [pluginResult setKeepCallbackAsBool:YES];
            [self.commandDelegate sendPluginResult:pluginResult callbackId:self.callbackId];
        }
    }];
}

// Handle updated push credentials
- (void)pushRegistry:(PKPushRegistry *)registry didUpdatePushCredentials: (PKPushCredentials *)credentials forType:(NSString *)type {
    NSLog(@"VoipPush Plugin token received: %@", credentials.token);
    if ([credentials.token length] != 32) {
        NSLog(@"Incorrect push token length: %lu", (unsigned long)(credentials.token.length));
        return;
    }
    
    // https://stackoverflow.com/questions/9372815/how-can-i-convert-my-device-token-nsdata-into-an-nsstring/9372848#9372848
    const unsigned *tokenBytes = [credentials.token bytes];
    NSString *token = [NSString stringWithFormat:@"%08x%08x%08x%08x%08x%08x%08x%08x",
                        ntohl(tokenBytes[0]), ntohl(tokenBytes[1]), ntohl(tokenBytes[2]),
                        ntohl(tokenBytes[3]), ntohl(tokenBytes[4]), ntohl(tokenBytes[5]),
                        ntohl(tokenBytes[6]), ntohl(tokenBytes[7])];
    
    NSMutableDictionary* pushMessage = [NSMutableDictionary dictionaryWithCapacity:2];
    [pushMessage setObject:token forKey:@"token"];
    [pushMessage setObject:credentials.type forKey:@"type"];

    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:pushMessage];
    [pluginResult setKeepCallbackAsBool:YES];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:self.callbackId];
}

- (void)pushRegistry:(PKPushRegistry *)registry didReceiveIncomingPushWithPayload:(PKPushPayload *)payload forType:(NSString *)type {
	// Process the received push
    NSLog(@"VoipPush Plugin incoming payload: %@", payload.dictionaryPayload);

    if ([payload.type isEqualToString:@"PKPushTypeVoIP"]) {
        NSMutableDictionary* pushMessage = [NSMutableDictionary dictionaryWithCapacity:2];
        [pushMessage setObject:payload.dictionaryPayload forKey:@"payload"];
        [pushMessage setObject:payload.type forKey:@"type"];

        CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:pushMessage];
        [pluginResult setKeepCallbackAsBool:YES];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:self.callbackId];
    } else {
        CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Invalid push type received"];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:self.callbackId];
    }
}

@end
