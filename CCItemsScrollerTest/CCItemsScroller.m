//
//  CCItemsScroller.m
//
//  Created by Aleksander Bykin on 26.06.12.
//  Copyright 2012. All rights reserved.
//

#import "CCItemsScroller.h"

enum
{
    kCCScrollLayerStateIdle,
    kCCScrollLayerStateSliding
};

@implementation CCItemsScroller{
    CGRect _rect;
    int _state;
    CGPoint _startSwipe;
    CGPoint _offset;
    CGSize _itemSize;
    NSInteger _lastSelectedIndex;
}

@synthesize delegate = _delegate;
@synthesize orientation = _orientation;
@synthesize isSwallowTouches = _isSwallowTouches;

+(id)itemsScrollerWithItems:(NSArray *)items andOrientation:(CCItemsScrollerOrientations)orientation andRect:(CGRect)rect{
    return [[self alloc] initWithItems:items andOrientation:(CCItemsScrollerOrientations)orientation andRect:rect];
}

-(id)initWithItems:(NSArray *)items andOrientation:(CCItemsScrollerOrientations)orientation andRect:(CGRect)rect{
    self = [super init];
    
    if(self){
        _rect = rect;
        _orientation = orientation;
        _isSwallowTouches = YES;
        
        self.isTouchEnabled = YES;
        [self updateItems:items];
    }
    
    return self;
}

-(void)updateItems:(NSArray*)items{
    int i = 0;
    CGFloat x = 0;
    CGFloat y = 0;
    
    for (CCNode *item in items)
    {
        if(i == 0){
            int csWidth = 0;
            int csHeight = 0;
            
            _itemSize = CGSizeMake(item.contentSize.width, item.contentSize.height);
            
            if(_orientation == CCItemsScrollerHorizontal){
                csWidth = items.count*_itemSize.width;
                csHeight = _rect.size.height;
            }
            
            if(_orientation == CCItemsScrollerVertical){
                csWidth = _rect.size.width;
                csHeight = items.count*_itemSize.height;
            }
            
            self.contentSize = CGSizeMake(csWidth, csHeight);
        }
        
        if (_orientation == CCItemsScrollerHorizontal) {
            x = (i * item.contentSize.width);
        }
        
        if(_orientation == CCItemsScrollerVertical){
            y = (i * item.contentSize.height);
        }
        
        item.tag = i;
        item.position = ccp(x, y);
        
        if (!item.parent)
            [self addChild:item z:i tag:i];
        
        ++i;
    }
    
    _offset.x = _rect.origin.x;
    _offset.y = _rect.origin.y;
    
    if(_orientation == CCItemsScrollerHorizontal)
        self.position = ccp(_rect.origin.x, _rect.origin.y);
    
    if(_orientation == CCItemsScrollerVertical){
        _offset.y = -(self.contentSize.height-_rect.size.height-_rect.origin.y);
        self.position = ccp(_rect.origin.x, _offset.y);
    }
}

-(void) visit
{
    CGRect _glRect = CC_RECT_POINTS_TO_PIXELS(_rect);
    
    //glPushMatrix();
    glEnable(GL_SCISSOR_TEST);
    glScissor(_glRect.origin.x, _glRect.origin.y, _glRect.size.width, _glRect.size.height);
    
    [super visit];
    
    glDisable(GL_SCISSOR_TEST);
    //glPopMatrix();
}

- (void)registerWithTouchDispatcher
{	
    CCTouchDispatcher *dispatcher = [[CCDirector sharedDirector] touchDispatcher];
    int priority = INT_MIN - 1;
    
    [dispatcher addTargetedDelegate:self priority:priority swallowsTouches:_isSwallowTouches];
}

-(BOOL) ccTouchBegan:(UITouch *)touch withEvent:(UIEvent *)event
{
    CGPoint touchPoint = [touch locationInView:[touch view]];
    touchPoint = [[CCDirector sharedDirector] convertToGL:touchPoint];    
    
    // Swallow touches
    BOOL result = (CGRectContainsPoint(_rect, touchPoint) || !_isSwallowTouches);
    
    if(result)
        _state = kCCScrollLayerStateIdle;    
    
    return result;    
}

- (void)ccTouchMoved:(UITouch *)touch withEvent:(UIEvent *)event
{
    CGPoint touchPoint = [touch locationInView:[touch view]];
    touchPoint = [[CCDirector sharedDirector] convertToGL:touchPoint];    
    
    if ( _state != kCCScrollLayerStateSliding )
    {
        _state = kCCScrollLayerStateSliding;
        
        _startSwipe = CGPointMake(_offset.x - touchPoint.x, _offset.y - touchPoint.y);
        
        if ([_delegate respondsToSelector:@selector(scrollLayerScrollingStarted:)])
            [_delegate itemsScrollerScrollingStarted:self];
    }
    
    if (_state == kCCScrollLayerStateSliding)
    {
        if(_orientation == CCItemsScrollerHorizontal){
            _offset.x = _startSwipe.x + touchPoint.x;
            
            if(_offset.x > _rect.origin.x){
                _offset.x = _rect.origin.x;
            }
            else if(_offset.x < -(self.contentSize.width-_rect.size.width-_rect.origin.x)){
                _offset.x = -(self.contentSize.width-_rect.size.width-_rect.origin.x);
            }
        }
        
        if(_orientation == CCItemsScrollerVertical){
            _offset.y = _startSwipe.y + touchPoint.y;
            
            if(_startSwipe.y < touchPoint.y){
                if (_offset.y > _rect.origin.y) {
                    _offset.y = _rect.origin.y;
                }else
                    if (_offset.y < -(self.contentSize.height-_rect.size.height-_rect.origin.y))
                    {
                        _offset.y = -(self.contentSize.height-_rect.size.height-_rect.origin.y);
                    }
            }
            else {
                if (_offset.y > _rect.origin.y) {
                    _offset.y = _rect.origin.y;
                }
            }
        }
        
        self.position = ccp(_offset.x, _offset.y);
    }
}

-(void)ccTouchEnded:(UITouch *)touch withEvent:(UIEvent *)event{
    CGPoint touchPoint = [touch locationInView:[touch view]];
    touchPoint = [[CCDirector sharedDirector] convertToGL:touchPoint];    
    
    CGFloat touchX = 0;
    CGFloat touchY = 0;
    
    if(_orientation == CCItemsScrollerHorizontal){
        touchY = touchPoint.y;
        touchX = self.position.x*-1 + touchPoint.x;
    }
    
    if(_orientation == CCItemsScrollerVertical){
        touchX = touchPoint.x;
        touchY = self.position.y - touchPoint.y;
        
        if(touchY < 0)
            touchY *= -1;
    }
    
    for (CCLayer *item in self.children) {
        BOOL isX = NO;
        BOOL isY = NO;
        
        if(_orientation == CCItemsScrollerHorizontal){
            isX = (touchX >= item.position.x && touchX <= item.position.x + item.contentSize.width);
            isY = (touchY >= self.position.y && touchY <= self.position.y + item.contentSize.height);
        }
        
        if(_orientation == CCItemsScrollerVertical){        
            isX = (touchX >= item.position.x && touchX <= item.contentSize.width);
            isY = (touchY >= item.position.y && touchY <= item.position.y + item.contentSize.height);
        }
        
        if(isX && isY){
            [self setSelectedItemIndex:item.tag];
            
            break;
        }
    }
}

-(void)setSelectedItemIndex:(NSInteger)index{
    id currentChild = [self getChildByTag:index];
    id lastSelectedChild = [self getChildByTag:_lastSelectedIndex];
    
    if([lastSelectedChild respondsToSelector:@selector(setIsSelected:)])
    {
        [lastSelectedChild setIsSelected:NO];
    }
    
    if([currentChild respondsToSelector:@selector(setIsSelected:)]){
        [currentChild setIsSelected:YES];
    }
    
    _lastSelectedIndex = index;
    
    if([_delegate respondsToSelector:@selector(itemsScroller:didSelectItemIndex:)])
        [_delegate itemsScroller:self didSelectItemIndex:index];
}

@end
