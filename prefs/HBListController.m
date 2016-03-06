#import "HBListController.h"
#import "HBTintedTableCell.h"
#import "UINavigationItem+HBTintAdditions.h"
#import <libprefs/prefs.h>
#import <version.h>

UIStatusBarStyle previousStatusBarStyle = -1;
BOOL changedStatusBarStyle = NO;
BOOL translucentNavigationBar = YES;

@class HBRootListController;

@implementation HBListController {
	UIColor *_tableViewCellTextColor;
	UIColor *_tableViewCellBackgroundColor;
	UIColor *_tableViewCellSelectionColor;
}

#pragma mark - Constants

+ (NSString *)hb_specifierPlist {
	return nil; // Totally makes sense.
}

+ (UIColor *)hb_tintColor {
	return nil;
}

+ (UIColor *)hb_navigationBarTintColor {
	return [self hb_tintColor];
}

+ (BOOL)hb_invertedNavigationBar {
	return NO;
}

+ (UIColor *)hb_tableViewCellTextColor {
	return nil;
}

+ (UIColor *)hb_tableViewCellBackgroundColor {
	return nil;
}

+ (UIColor *)hb_tableViewCellSeparatorColor {
	return nil;
}

+ (UIColor *)hb_tableViewCellSelectionColor {
	return nil;
}

+ (UIColor *)hb_tableViewBackgroundColor {
	return nil;
}

+ (BOOL)hb_translucentNavigationBar {
	return YES;
}

#pragma mark - Loading specifiers

- (void)_loadSpecifiersFromPlistIfNeeded {
	if (_specifiers || ![self.class hb_specifierPlist]) {
		return;
	}

	_specifiers = [[self loadSpecifiersFromPlistName:[self.class hb_specifierPlist] target:self] retain];
}

- (NSArray *)specifiers {
	[self _loadSpecifiersFromPlistIfNeeded];
	return _specifiers;
}

- (NSArray *)loadSpecifiersFromPlistName:(NSString *)plistName target:(PSListController *)target bundle:(NSBundle *)bundle {
	// override the loading mechanism so we can add additional features
	NSArray *specifiers = [super loadSpecifiersFromPlistName:plistName target:target bundle:bundle];
	NSMutableArray *specifiersToRemove = [NSMutableArray array];

	for (PSSpecifier *specifier in specifiers) {
		// libprefs defines some filters we can take advantage of
		if (![PSSpecifier environmentPassesPreferenceLoaderFilter:specifier.properties[PLFilterKey]]) {
			[specifiersToRemove addObject:specifier];
		}
	}

	// if we have specifiers to remove
	if (specifiersToRemove.count > 0) {
		// make a mutable copy of the specifiers
		NSMutableArray *newSpecifiers = [[specifiers mutableCopy] autorelease];

		// remove all the filtered specifiers
		[newSpecifiers removeObjectsInArray:specifiersToRemove];

		// and assign it to specifiers again
		specifiers = newSpecifiers;
	}

	return specifiers;
}

#pragma mark - UIViewController

- (instancetype)init {
	self = [super init];

	if (self) {
		UINavigationItem *navigationItem = self.navigationItem;
		navigationItem.hb_tintColor = [[self.class hb_tintColor] copy];
		navigationItem.hb_navigationBarBackgroundColor = [[self.class hb_invertedNavigationBar] ? [self.class hb_navigationBarTintColor] : nil copy];
		navigationItem.hb_navigationBarTintColor = [[self.class hb_invertedNavigationBar] ? [UIColor colorWithWhite:247.f / 255.f alpha:1] : [self.class hb_navigationBarTintColor] copy];
		navigationItem.hb_navigationBarTextColor = [[self.class hb_invertedNavigationBar] ? [UIColor whiteColor] : nil copy];
	}

	return self;
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];

	UIColor *tintColor = nil;

	BOOL changeStatusBar = NO;

	UIColor *tableViewCellSeparatorColor = nil;
	UIColor *tableViewBackgroundColor = nil;

	// enumerate backwards over the navigation stack
	for (HBListController *viewController in self.navigationController.viewControllers.reverseObjectEnumerator) {
		// if we have a tint color, grab it and stop there
		if (!tintColor && [viewController.class respondsToSelector:@selector(hb_tintColor)] && [viewController.class hb_tintColor]) {
			tintColor = [viewController.class hb_tintColor];
		}

		// if we have a hb_translucentNavigationBar value, grab it
		if ([viewController.class respondsToSelector:@selector(hb_translucentNavigationBar)] && ![viewController.class hb_translucentNavigationBar]) {
			translucentNavigationBar = NO;
		}

		// if we have a YES hb_invertedNavigationBar value, grab it and stop there
		if ([viewController.class respondsToSelector:@selector(hb_invertedNavigationBar)] && [viewController.class hb_invertedNavigationBar]) {
			changeStatusBar = YES;
		}

		if (!_tableViewCellTextColor && [viewController.class respondsToSelector:@selector(hb_tableViewCellTextColor)] && [viewController.class hb_tableViewCellTextColor]) {
			_tableViewCellTextColor = [viewController.class hb_tableViewCellTextColor];
		}

		if (!_tableViewCellBackgroundColor && [viewController.class respondsToSelector:@selector(hb_tableViewCellBackgroundColor)] && [viewController.class hb_tableViewCellBackgroundColor]) {
			_tableViewCellBackgroundColor = [viewController.class hb_tableViewCellBackgroundColor];
		}

		if (!_tableViewCellSelectionColor && [viewController.class respondsToSelector:@selector(hb_tableViewCellSelectionColor)] && [viewController.class hb_tableViewCellSelectionColor]) {
			_tableViewCellSelectionColor = [viewController.class hb_tableViewCellSelectionColor];
		}

		if ([viewController.class respondsToSelector:@selector(hb_tableViewCellSeparatorColor)] && [viewController.class hb_tableViewCellSeparatorColor]) {
			tableViewCellSeparatorColor = [viewController.class hb_tableViewCellSeparatorColor];
		}

		if ([viewController.class respondsToSelector:@selector(hb_tableViewBackgroundColor)] && [viewController.class hb_tableViewBackgroundColor]) {
			tableViewBackgroundColor = [viewController.class hb_tableViewBackgroundColor];
		}
	}

	if (tableViewCellSeparatorColor) {
		self.table.separatorColor = tableViewCellSeparatorColor;
	}

	if (tableViewBackgroundColor) {
		self.table.backgroundColor = tableViewBackgroundColor;
	}

	self.realNavigationController.navigationBar.translucent = translucentNavigationBar;
	self.edgesForExtendedLayout = translucentNavigationBar ? UIRectEdgeAll : UIRectEdgeNone;

	// if we have a tint color, apply it
	if (tintColor) {
		self.view.tintColor = tintColor;
		[UISwitch appearanceWhenContainedIn:self.class, nil].onTintColor = tintColor;
	}

	// if the status bar is about to change to something custom, or we don’t
	// already know the previous status bar style, set it here
	previousStatusBarStyle = [UIApplication sharedApplication].statusBarStyle;

	// set the status bar style accordingly
	if (changeStatusBar) {
		[UIApplication sharedApplication].statusBarStyle = UIStatusBarStyleLightContent;
	}
}

- (void)viewWillDisappear:(BOOL)animated {
	[super viewWillDisappear:animated];

	[UIApplication sharedApplication].statusBarStyle = previousStatusBarStyle;

	if (!translucentNavigationBar) {
		self.realNavigationController.navigationBar.translucent = YES;
		self.edgesForExtendedLayout = UIRectEdgeAll;
	}
}

#pragma mark - Navigation controller quirks

/*
 The layout of Settings is weird on iOS 8. On iPhone, the actual navigation
 controller is the parent of self.navigationController. On iPad, it remains
 how it's always been.
*/
- (UINavigationController *)realNavigationController {
	UINavigationController *navigationController = self.navigationController;

	while (navigationController.navigationController) {
		navigationController = navigationController.navigationController;
	}

	return navigationController;
}

#pragma mark - UITableViewDelegate

/*
 Fixes weird iOS 7 glitch, a little neater than before, and ideally preventing
 crashes on iPads and older devices.
*/
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	[super tableView:tableView didSelectRowAtIndexPath:indexPath];
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	UITableViewCell *cell = [super tableView:tableView cellForRowAtIndexPath:indexPath];

	if (_tableViewCellSelectionColor) {
		UIView *selectionView = [[[UIView alloc] init] autorelease];
		selectionView.backgroundColor = _tableViewCellSelectionColor;
		cell.selectedBackgroundView = selectionView;
	}

	if (_tableViewCellTextColor) {
		cell.textLabel.textColor = _tableViewCellTextColor;
	}

	if (_tableViewCellBackgroundColor) {
		cell.backgroundColor = _tableViewCellBackgroundColor;
	}

	return cell;
}

#pragma mark - Memory management

- (void)dealloc {
	[_tableViewCellTextColor release];
	[_tableViewCellBackgroundColor release];
	[_tableViewCellSelectionColor release];

	[super dealloc];
}

@end
