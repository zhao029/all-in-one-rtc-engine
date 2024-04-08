//
//  TXLiveNewViewController.m
//  TXLiteAVDemo
//
//  Created by ericxwli on 2019/1/9.
//  Copyright © 2019年 Tencent. All rights reserved.
//
#ifdef ENABLE_PLAY
#import "TXLiveNewViewController.h"
#import "ColorMacro.h"
#import "UIView+Additions.h"
#import "TXLivePlayerViewController.h"
#define KEY_CURRENT_USERID      @"__current_userid__"
@interface TXLiveNewViewController () <UITextFieldDelegate>
{
    UILabel           *_tipLabel;
    UITextField       *_roomIdTextField;
    UITextField       *_userIdTextField;
    UIButton          *_joinBtn;
    UIPickerView      *_userIdPicker;
    UISegmentedControl *_segmentedControl;
    BOOL              _isMain;
}
@end

@implementation TXLiveNewViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = @"直播";
    [self.view setBackgroundColor:UIColorFromRGB(0x333333)];
    
    _tipLabel = [[UILabel alloc] initWithFrame:CGRectMake(18, 100, 200, 30)];
    _tipLabel.textColor = UIColorFromRGB(0x999999);
    _tipLabel.text = @"请输入房间号：";
    _tipLabel.textAlignment = NSTextAlignmentLeft;
    _tipLabel.font = [UIFont systemFontOfSize:16];
    [self.view addSubview:_tipLabel];

    UIView *paddingView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 18, 40)];
    _roomIdTextField = [[UITextField alloc] initWithFrame:CGRectMake(0, 136, self.view.width, 40)];
    _roomIdTextField.delegate = self;
    _roomIdTextField.leftView = paddingView;
    _roomIdTextField.leftViewMode = UITextFieldViewModeAlways;
    _roomIdTextField.placeholder = @"901";
    _roomIdTextField.backgroundColor = UIColorFromRGB(0x4a4a4a);
    _roomIdTextField.textColor = UIColorFromRGB(0x939393);
    _roomIdTextField.keyboardType = UIKeyboardTypeNumberPad;
    _roomIdTextField.clearButtonMode = UITextFieldViewModeWhileEditing;
    [self.view addSubview:_roomIdTextField];
    
    UILabel* userTipLabel = [[UILabel alloc] initWithFrame:CGRectMake(18, 182, 200, 30)];
    userTipLabel.textColor = UIColorFromRGB(0x999999);
    userTipLabel.text = @"请输入用户名：";
    userTipLabel.textAlignment = NSTextAlignmentLeft;
    userTipLabel.font = [UIFont systemFontOfSize:16];
    [self.view addSubview:userTipLabel];
    
    NSString* userId = [self getUserId];
    UIView *paddingView1 = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 18, 40)];
    _userIdTextField = [[UITextField alloc] initWithFrame:CGRectMake(0, 220, self.view.width, 40)];
    _userIdTextField.delegate = self;
    _userIdTextField.leftView = paddingView1;
    _userIdTextField.leftViewMode = UITextFieldViewModeAlways;
    _userIdTextField.text = userId;
    _userIdTextField.placeholder = @"12345";
    _userIdTextField.backgroundColor = UIColorFromRGB(0x4a4a4a);
    _userIdTextField.textColor = UIColorFromRGB(0x939393);
    _userIdTextField.clearButtonMode = UITextFieldViewModeWhileEditing;
    [self.view addSubview:_userIdTextField];
    
    _joinBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    _joinBtn.frame = CGRectMake(40, self.view.height - 70, self.view.width - 80, 50);
    _joinBtn.layer.cornerRadius = 8;
    _joinBtn.layer.masksToBounds = YES;
    _joinBtn.layer.shadowOffset = CGSizeMake(1, 1);
    _joinBtn.layer.shadowColor = UIColorFromRGB(0x019b5c).CGColor;
    _joinBtn.layer.shadowOpacity = 0.8;
    _joinBtn.backgroundColor = UIColorFromRGB(0x05a764);
    [_joinBtn setTitle:@"观看直播" forState:UIControlStateNormal];
    [_joinBtn addTarget:self action:@selector(onJoinBtnClicked:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_joinBtn];
    
    _segmentedControl=[[UISegmentedControl alloc] initWithFrame:CGRectMake(20, 300, 100, 30.0f) ];
    [_segmentedControl insertSegmentWithTitle:@"主流" atIndex:0 animated:YES];
    [_segmentedControl insertSegmentWithTitle:@"辅流" atIndex:1 animated:YES];
    _segmentedControl.segmentedControlStyle = UISegmentedControlStyleBar;
    _segmentedControl.selectedSegmentIndex = 0;
    [_segmentedControl addTarget:self action:@selector(Selectbutton:) forControlEvents:UIControlEventValueChanged];
    [self.view addSubview:_segmentedControl];
    _isMain = YES;

}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.navigationController.navigationBar.hidden = NO;
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    self.navigationController.navigationBar.hidden = YES;
}

- (void)onJoinBtnClicked:(UIButton *)sender{
    TXLivePlayerViewController *playVC = [TXLivePlayerViewController new];
    playVC.roomId = _roomIdTextField.text;
    playVC.userId = _userIdTextField.text;
    if (_isMain) {
        playVC.streamStr = @"main";
    }
    else{
        playVC.streamStr = @"aux";
    }
    [self.navigationController pushViewController:playVC animated:YES];
}
- (void)Selectbutton:(UISegmentedControl*)Seg{
    NSInteger Index = Seg.selectedSegmentIndex;
    switch (Index) {
        case 0:
            _isMain = YES;
            break;
        case 1:
            _isMain = NO;
            break;
        default:
            break;
    }
}
#pragma mark - UITextFieldDelegate

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    return YES;
}

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string
{
    if (textField == _roomIdTextField) {
        NSCharacterSet *numbersOnly = [NSCharacterSet characterSetWithCharactersInString:@"9876543210"];
        NSCharacterSet *characterSetFromTextField = [NSCharacterSet characterSetWithCharactersInString:string];
        
        BOOL stringIsValid = [numbersOnly isSupersetOfSet:characterSetFromTextField];
        return stringIsValid;
    }
    return YES;
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [self.view endEditing:NO];
}
- (NSString *)getUserId {
    NSString* userId = @"";
    NSObject *d = [[NSUserDefaults standardUserDefaults] objectForKey:KEY_CURRENT_USERID];
    if (d) {
        userId = [NSString stringWithFormat:@"%@", d];
    } else {
        double tt = [[NSDate date] timeIntervalSince1970];
        int user = ((uint64_t)(tt * 1000.0)) % 100000000;
        userId = [NSString stringWithFormat:@"%d", user];
        [[NSUserDefaults standardUserDefaults] setObject:userId forKey:KEY_CURRENT_USERID];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
    return userId;
}
/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
#endif
