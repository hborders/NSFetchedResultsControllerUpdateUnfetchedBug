//
//  HJBAppDelegate.m
//  NSFetchedResultsControllerUpdateUnfetchedBug
//
//  Created by Heath Borders on 12/23/12.
//
//

#import "HJBAppDelegate.h"
#import <CoreData/CoreData.h>

@interface HJBFoo : NSManagedObject

@property (nonatomic, retain) NSString *name;
@property (nonatomic, retain) NSNumber *show;

@end

@interface HJBAppDelegate () <NSFetchedResultsControllerDelegate>

@property (nonatomic, strong) NSPersistentStoreCoordinator *persistentStoreCoordinator;
@property (nonatomic, strong) NSManagedObjectContext *initialManagedObjectContext;
@property (nonatomic, strong) NSManagedObjectContext *fetchedResultsControllerManagedObjectContext;
@property (nonatomic, strong) NSFetchedResultsController *fetchedResultsController;

@end

@implementation HJBAppDelegate

#pragma mark - UIApplicationDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    self.window.backgroundColor = [UIColor whiteColor];
    self.window.rootViewController = [UIViewController new];
    
    NSAttributeDescription *nameAttributeDescription = [NSAttributeDescription new];
    [nameAttributeDescription setAttributeType:NSStringAttributeType];
    [nameAttributeDescription setIndexed:NO];
    [nameAttributeDescription setOptional:NO];
    [nameAttributeDescription setName:@"name"];
    
    NSAttributeDescription *showAttributeDescription = [NSAttributeDescription new];
    [showAttributeDescription setAttributeType:NSBooleanAttributeType];
    [showAttributeDescription setIndexed:YES];
    [showAttributeDescription setOptional:NO];
    [showAttributeDescription setName:@"show"];
    
    NSEntityDescription *fooEntityDescription = [NSEntityDescription new];
    [fooEntityDescription setManagedObjectClassName:@"HJBFoo"];
    [fooEntityDescription setName:@"HJBFoo"];
    [fooEntityDescription setProperties:@[
     nameAttributeDescription,
     showAttributeDescription,
     ]];
    
    NSManagedObjectModel *managedObjectModel = [NSManagedObjectModel new];
    [managedObjectModel setEntities:@[
     fooEntityDescription,
     ]];
    
    self.persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:managedObjectModel];
    NSError *error = nil;
    if ([self.persistentStoreCoordinator addPersistentStoreWithType:NSInMemoryStoreType
                                                      configuration:nil
                                                                URL:nil
                                                            options:nil
                                                              error:&error]) {
        self.initialManagedObjectContext = [NSManagedObjectContext new];
        [self.initialManagedObjectContext setPersistentStoreCoordinator:self.persistentStoreCoordinator];
        
        HJBFoo *foo1 = [NSEntityDescription insertNewObjectForEntityForName:@"HJBFoo"
                                                     inManagedObjectContext:self.initialManagedObjectContext];
        foo1.name = @"1";
        foo1.show = @YES;
        
        HJBFoo *foo2 = [NSEntityDescription insertNewObjectForEntityForName:@"HJBFoo"
                                                     inManagedObjectContext:self.initialManagedObjectContext];
        foo2.name = @"2";
        foo2.show = @NO;
        
        error = nil;
        if ([self.initialManagedObjectContext save:&error]) {
            NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:@"HJBFoo"];
            [fetchRequest setReturnsObjectsAsFaults:NO];
            
            error = nil;
            NSArray *initialFoos = [self.initialManagedObjectContext executeFetchRequest:fetchRequest
                                                                                   error:&error];
            if (initialFoos) {
                NSLog(@"Initial: %@", initialFoos);
                
                self.fetchedResultsControllerManagedObjectContext = [NSManagedObjectContext new];
                [self.fetchedResultsControllerManagedObjectContext setPersistentStoreCoordinator:self.persistentStoreCoordinator];
                
                NSFetchRequest *shownFetchRequest = [NSFetchRequest fetchRequestWithEntityName:@"HJBFoo"];
                [shownFetchRequest setPredicate:[NSPredicate predicateWithFormat:@"show == YES"]];
                [shownFetchRequest setSortDescriptors:@[
                 [NSSortDescriptor sortDescriptorWithKey:@"name"
                                               ascending:YES],
                 ]];
                
                self.fetchedResultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:shownFetchRequest
                                                                                    managedObjectContext:self.fetchedResultsControllerManagedObjectContext
                                                                                      sectionNameKeyPath:nil
                                                                                               cacheName:nil];
                self.fetchedResultsController.delegate = self;
                error = nil;
                if ([self.fetchedResultsController performFetch:&error]) {
                    NSLog(@"Initial fetchedObjects: %@", [self.fetchedResultsController fetchedObjects]);
                    
                    [[NSNotificationCenter defaultCenter] addObserver:self
                                                             selector:@selector(managedObjectContextDidSave:)
                                                                 name:NSManagedObjectContextDidSaveNotification
                                                               object:nil];
                    [[NSNotificationCenter defaultCenter] addObserver:self
                                                             selector:@selector(managedObjectContext2ObjectsDidChange:)
                                                                 name:NSManagedObjectContextObjectsDidChangeNotification
                                                               object:self.fetchedResultsControllerManagedObjectContext];
                    
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.5 * NSEC_PER_SEC),
                                   dispatch_get_main_queue(),
                                   ^(void){
                                       NSManagedObjectContext *managedObjectContext3 = [NSManagedObjectContext new];
                                       [managedObjectContext3 setPersistentStoreCoordinator:self.persistentStoreCoordinator];
                                       
                                       NSFetchRequest *foo2FetchRequest = [NSFetchRequest fetchRequestWithEntityName:@"HJBFoo"];
                                       [foo2FetchRequest setFetchLimit:1];
                                       [foo2FetchRequest setPredicate:[NSPredicate predicateWithFormat:@"name == %@",
                                                                       @"2"]];
                                       NSError *editingError = nil;
                                       NSArray *editingFoos = [managedObjectContext3 executeFetchRequest:foo2FetchRequest
                                                                                                   error:&editingError];
                                       if (editingFoos) {
                                           HJBFoo *editingFoo2 = [editingFoos objectAtIndex:0];
                                           editingFoo2.show = @YES;
                                           
                                           editingError = nil;
                                           if ([managedObjectContext3 save:&editingError]) {
                                               NSLog(@"Save succeeded. Expected (in order) managedObjectContextDidSave, controllerDidChangeContent, managedObjectContext2ObjectsDidChange");
                                           } else {
                                               NSLog(@"Editing save failed: %@ %@", [error localizedDescription], [error userInfo]);
                                           }
                                       } else {
                                           NSLog(@"Editing fetch failed: %@ %@", [error localizedDescription], [error userInfo]);
                                       }
                                       
                                   });
                } else {
                    NSLog(@"Failed initial fetch: %@ %@", [error localizedDescription], [error userInfo]);
                }
            } else {
                NSLog(@"Failed to performFetch: %@ %@", [error localizedDescription], [error userInfo]);
            }
        } else {
            NSLog(@"Failed to save initial state: %@ %@", [error localizedDescription], [error userInfo]);
        }
    } else {
        NSLog(@"Failed to add persistent store: %@ %@", [error localizedDescription], [error userInfo]);
    }
    
    [self.window makeKeyAndVisible];
    return YES;
}

#pragma mark - NSFetchedResultsControllerDelegate

- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller {
    NSLog(@"controllerDidChangeContent: %@",
          [self.fetchedResultsController fetchedObjects]);
}

#pragma mark - notifications

- (void)managedObjectContextDidSave:(NSNotification *)notification {
    NSManagedObjectContext *managedObjectContext = [notification object];
    if (([managedObjectContext persistentStoreCoordinator] == self.persistentStoreCoordinator) &&
        (managedObjectContext != self.fetchedResultsControllerManagedObjectContext)) {
        NSLog(@"managedObjectContextDidSave: %@", notification);
        
        // Fix/workaround from http://stackoverflow.com/questions/3923826/nsfetchedresultscontroller-with-predicate-ignores-changes-merged-from-different/3927811#3927811
        for(NSManagedObject *object in [[notification userInfo] objectForKey:NSUpdatedObjectsKey]) {
            [[self.fetchedResultsControllerManagedObjectContext objectWithID:[object objectID]] willAccessValueForKey:nil];
        }
        [self.fetchedResultsControllerManagedObjectContext mergeChangesFromContextDidSaveNotification:notification];
    }
}

- (void)managedObjectContext2ObjectsDidChange:(NSNotification *)notification {
    NSLog(@"managedObjectContext2ObjectsDidChange: %@", notification);
}

@end

@implementation HJBFoo

@dynamic name;
@dynamic show;

@end
