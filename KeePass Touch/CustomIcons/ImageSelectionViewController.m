/*
 * Copyright 2017-2019 Innervate UG & Co. KG. All rights reserved.
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

#import "ImageSelectionViewController.h"

@interface ImageSelectionViewController ()
{
    UIScrollView *_scrollView;
}
@end

@implementation ImageSelectionViewController

@synthesize imageSelectionView = _imageSelectionView;

- (void)viewDidLoad {
    
    _scrollView = [[UIScrollView alloc] init];
    if (@available(iOS 13.0, *)) {
        _scrollView.backgroundColor = UIColor.systemBackgroundColor;
    } else {
        // Fallback on earlier versions
        _scrollView.backgroundColor = UIColor.whiteColor;
    }
    _scrollView.alwaysBounceHorizontal = NO;
    _imageSelectionView = [[ImageSelectionView alloc] init];
    _imageSelectionView.layoutDelegate = self;
    _imageSelectionView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [_scrollView addSubview:_imageSelectionView];
    [self.view addSubview:_scrollView];
    
    self.title = NSLocalizedString(@"Images", nil);
    self.customIndex = 0;
}

- (void)viewDidLayoutSubviews {
    _scrollView.frame = self.view.bounds;
    _imageSelectionView.frame = _scrollView.frame;
}

- (ImageSelectionView *)imageSelectionView {
    return _imageSelectionView;
}

- (void)didFinishLayout
{
    if(self.customIndex != 0)
    {
        [_imageSelectionView selectedCustomIndex:self.customIndex];
    }
    
}


@end
