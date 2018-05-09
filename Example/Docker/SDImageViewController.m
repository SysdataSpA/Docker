//
//  SDImageViewController.m
//  Docker
//
//  Created by Francesco Ceravolo on 10/04/17.
//  Copyright © 2017 francescoceravolo. All rights reserved.
//

#import "SDImageViewController.h"
#import "SDTableViewCell.h"

@interface SDImageViewController ()<UITableViewDelegate, UITableViewDataSource>

@property (weak, nonatomic) IBOutlet UITableView *tableView;

@property (nonatomic, strong) NSArray<NSString*>* imageUrls;

@end

@implementation SDImageViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.automaticallyAdjustsScrollViewInsets = NO;
    
    self.imageUrls = @[
                       @"http://images.freeimages.com/images/previews/aaa/spanish-village-street-1445758.jpg",
                       @"http://media.istockphoto.com/photos/castillala-manchaspain-picture-id535260987",
                       @"http://media.istockphoto.com/photos/fornalutx-view-to-the-hills-around-picture-id529234985",
                       @"http://media.istockphoto.com/photos/beautiful-village-in-spain-picture-id182174577",
                       @"http://media.istockphoto.com/photos/colorful-banners-decorations-between-balconies-over-a-street-picture-id188070898",
                       @"http://media.istockphoto.com/photos/lights-at-night-in-snowy-hills-in-sierra-nevada-picture-id469817092",
                       @"http://media.istockphoto.com/photos/colorful-banners-decorations-between-balconies-over-a-street-picture-id188070898",
                       @"http://images.freeimages.com/images/previews/aaa/spanish-village-street-1445758.jpg",
                       @"http://media.istockphoto.com/photos/castillala-manchaspain-picture-id535260987",
                       @"http://media.istockphoto.com/photos/fornalutx-view-to-the-hills-around-picture-id529234985",
                       @"http://media.istockphoto.com/photos/beautiful-village-in-spain-picture-id182174577",
                       @"http://media.istockphoto.com/photos/colorful-banners-decorations-between-balconies-over-a-street-picture-id188070898",
                       @"http://media.istockphoto.com/photos/lights-at-night-in-snowy-hills-in-sierra-nevada-picture-id469817092",
                       @"http://media.istockphoto.com/photos/colorful-banners-decorations-between-balconies-over-a-street-picture-id188070898",@"http://images.freeimages.com/images/previews/aaa/spanish-village-street-1445758.jpg",
                       @"https://cdn-images-1.medium.com/max/2000/1*BR2RiTRoYor9xSrzEgxLWQ.jpeg",
                       @"https://cc-media-foxit.fichub.com/image/floptv/1ea44b90-3ab3-464e-a601-f9747470a4cb/immagini-divertenti-whatsapp-22.jpg",
                       @"http://www.pixolo.it/wp-content/uploads/2012/07/4_Cute_Cats_1440x900_4e23cbef51a8e.jpg",
                       @"http://www.pixolo.it/wp-content/uploads/2012/06/Seals_10_1920x1080_4fcc49e997b00.jpg",
                       @"https://cdn-images-1.medium.com/max/1200/1*oWwVkc2TjKU2fDRUPSWErw.jpeg",
                       @"https://assets.vg247.it/current//2017/07/praythemightyseaalt.png",
                       @"http://img2.tgcom24.mediaset.it/binary/fotogallery/ign/69.$plit/C_2_fotogallery_3085814_0_image.jpg?20180207174015",
                       @"https://images.wired.it/wp-content/uploads/2015/12/1451471710_gatto_sbadiglio.jpg",
                       @"http://img.liberoquotidiano.it/resizer/-1/-1/true/16637748-LiveLeakcom-RareWhiteMooseTakesaDipinaSwedishLakmp4.jpg--.jpg",
                       @"https://www.iloveimg.com/images/home.jpg",
                       @"http://www.superedo.it/sfondi/sfondi/Animali/Gattini/gattini_40.jpg",
                       @"http://www.superedo.it/sfondi/sfondi/Uccelli/Papere/papere_21.jpg",
                       @"https://images.everyeye.it/img-notizie/immagini-dallo-spazio-foto-video-dell-italia-giorno-notte-v6-308910-1280x720.jpg",
                       @"https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcShj0LUgRR-DW7aE1Wzhom9BaoDHnAFGjWIYue0xlQ-2XWoQxii",
                       @"https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcTwoMFSo4_e52oSSka65X2qkQnjnAcLWqGlnh22vk0vsFojPL4q",
                       @"https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcTOt8xRcAp3SE9-qhMPeog-npaJ1aBj603x0odVfiKL-8PKz0Rx6w",
                       @"http://www.pixolo.it/wp-content/uploads/2012/07/wallpaper-1667348.jpg",
                       @"https://images.everyeye.it/img-notizie/il-team-xbox-lavora-per-facilitare-condivisione-immagini-sui-social-v3-312908.jpg",
                       @"http://www.rossellamarangoni.it/wop/galleria/primavera/fuji-a-primavera.jpg",
                       @"https://images.everyeye.it/img-notizie/pixark-prime-immagini-nuovi-dettagli-sullo-spin-off-sandbox-ark-survival-evolved-v3-318812.jpg",
                       @"https://paroledisaggezza.altervista.org/wp-content/uploads/2016/05/frasi-e-immagini-facebook-whatsapp-social.jpg",
                       @"https://i.ytimg.com/vi/jUm5gVtL5AE/maxresdefault.jpg",
                       @"https://i.ytimg.com/vi/eBz_s4k17J4/maxresdefault.jpg",
                       @"https://www.dolomiten.net/it/images/foto/immagini-dolomiti.jpg"
                      ];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    [self.tableView reloadData];
    
    
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (NSInteger) tableView:(UITableView*)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.imageUrls.count;
}

- (UITableViewCell*) tableView:(UITableView*)tableView cellForRowAtIndexPath:(NSIndexPath*)indexPath
{
    SDTableViewCell* cell = [tableView dequeueReusableCellWithIdentifier:@"cell"];
    
    NSString* urlString = [self.imageUrls objectAtIndex:indexPath.row];
    
    cell.downloadImageView.showActivityIndicatorWhileLoading = YES;
    cell.downloadImageView.showLocalImageBeforeCheckingValidity = YES;
    cell.downloadImageView.placeHolderImage = nil;
    //    cell.downloadImageView.downloadOptions = DownloadOperationOptionForceDownload;
    
    [cell.downloadImageView setImageWithURLString:urlString completion:^(NSString* urlString, UIImage* image, DownloadOperationResultType resultType) {
    }];
    return cell;
}

@end
