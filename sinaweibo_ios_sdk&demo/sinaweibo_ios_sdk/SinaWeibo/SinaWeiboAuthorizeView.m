//
//  SinaWeiboAuthorizeView.m
//  sinaweibo_ios_sdk
//
//  Created by Wade Cheng on 4/19/12.
//  Copyright (c) 2012 SINA. All rights reserved.
//

#import "SinaWeiboAuthorizeView.h"
#import "SinaWeiboRequest.h"
#import "SinaWeibo.h"
#import "SinaWeiboConstants.h"
#import <QuartzCore/QuartzCore.h>

@implementation SinaWeiboAuthorizeView

@synthesize delegate;

#pragma mark - Memory management

- (id)init
{
    if ((self = [super init]))
    {
        self.backgroundColor = [UIColor clearColor];
        self.autoresizesSubviews = YES;
        self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        self.contentMode = UIViewContentModeRedraw;
            
        webView = [[UIWebView alloc] init];
        webView.delegate = self;
        webView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [self addSubview:webView];
        [webView release];
        
        indicatorView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:
                    UIActivityIndicatorViewStyleGray];
        indicatorView.autoresizingMask =
            UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin
            | UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
        [self addSubview:indicatorView];
    }
    
    return self;
}

- (void)dealloc
{
    [authParams release], authParams = nil;
    [appRedirectURI release], appRedirectURI = nil;
	[tempController release], tempController = nil;
    
    [super dealloc];
}

- (id)initWithAuthParams:(NSDictionary *)params
                delegate:(id<SinaWeiboAuthorizeViewDelegate>)_delegate
{
    if ((self = [self init]))
    {
        self.delegate = _delegate;
        authParams = [params copy];
        appRedirectURI = [[authParams objectForKey:@"redirect_uri"] retain];
    }
    return self;
}

#pragma mark - Activity Indicator

- (void)showIndicator
{
    [indicatorView sizeToFit];
    [indicatorView startAnimating];
    indicatorView.center = webView.center;	
}

- (void)hideIndicator
{
    [indicatorView stopAnimating];
}

#pragma mark - Show / Hide

- (void)load
{
    NSString *authPagePath = [SinaWeiboRequest serializeURL:kSinaWeiboWebAuthURL
                                                     params:authParams httpMethod:@"GET"];
    [webView loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:authPagePath]]];
}

- (void)_showWithViewController:(UIViewController *)controller
{
	if (tempController) {
		[tempController release];
		tempController = nil;
	}
	tempController = [[UIViewController alloc] initWithNibName:nil bundle:nil];
	UINavigationBar *navBar = [[[UINavigationBar alloc] initWithFrame:CGRectMake(0, 0, 320, 44)] autorelease];
	UINavigationItem *item = [[[UINavigationItem alloc] initWithTitle:@"新浪微博授权"] autorelease];
	item.leftBarButtonItem = [[[UIBarButtonItem alloc] initWithTitle:@" 取消 " style:UIBarButtonItemStyleBordered target:self action:@selector(cancel)] autorelease];
	navBar.items = @[item];
	[tempController.view addSubview:navBar];
	self.frame = CGRectMake(0, 44, 320, CGRectGetHeight(tempController.view.frame)-44);
	[tempController.view addSubview:self];
	[controller presentModalViewController:tempController animated:YES];
}

- (void)showWithViewController:(UIViewController *)controller
{
	[self performSelectorOnMainThread:@selector(_showWithViewController:) withObject:controller waitUntilDone:NO];

    [self load];
    
	[self showIndicator];
}

- (void)_hide
{
    [tempController dismissViewControllerAnimated:YES completion:^{
		[tempController release];
		tempController = nil;
	}];
}

- (void)hide
{
    [webView stopLoading];
    
    [self performSelectorOnMainThread:@selector(_hide) withObject:nil waitUntilDone:NO];
}

- (void)cancel
{
    [self hide];
    [delegate authorizeViewDidCancel:self];
}

#pragma mark - UIWebView Delegate

- (void)webViewDidFinishLoad:(UIWebView *)aWebView
{
	[self hideIndicator];
}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error
{
    [self hideIndicator];
}

- (BOOL)webView:(UIWebView *)aWebView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType
{
    NSString *url = request.URL.absoluteString;
    NSLog(@"url = %@", url);
    
    NSString *siteRedirectURI = [NSString stringWithFormat:@"%@%@", kSinaWeiboSDKOAuth2APIDomain, appRedirectURI];
    
    if ([url hasPrefix:appRedirectURI] || [url hasPrefix:siteRedirectURI])
    {
        NSString *error_code = [SinaWeiboRequest getParamValueFromUrl:url paramName:@"error_code"];
        
        if (error_code)
        {
            NSString *error = [SinaWeiboRequest getParamValueFromUrl:url paramName:@"error"];
            NSString *error_uri = [SinaWeiboRequest getParamValueFromUrl:url paramName:@"error_uri"];
            NSString *error_description = [SinaWeiboRequest getParamValueFromUrl:url paramName:@"error_description"];
            
            NSDictionary *errorInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                                       error, @"error",
                                       error_uri, @"error_uri",
                                       error_code, @"error_code",
                                       error_description, @"error_description", nil];
            
            [self hide];
            [delegate authorizeView:self didFailWithErrorInfo:errorInfo];
        }
        else
        {
            NSString *code = [SinaWeiboRequest getParamValueFromUrl:url paramName:@"code"];
            if (code)
            {
                [self hide];
                [delegate authorizeView:self didRecieveAuthorizationCode:code];
            }
        }
        
        return NO;
    }
    
    return YES;
}

@end
