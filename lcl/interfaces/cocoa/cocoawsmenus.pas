{ $Id: Cocoawsmenus.pp 15309 2008-06-04 22:12:59Z vincents $}
{
 *****************************************************************************
 *                               CocoaWSMenus.pp                             *
 *                               ------------                                * 
 *                                                                           *
 *                                                                           *
 *****************************************************************************

 *****************************************************************************
  This file is part of the Lazarus Component Library (LCL)

  See the file COPYING.modifiedLGPL.txt, included in this distribution,
  for details about the license.
 *****************************************************************************
}
unit CocoaWSMenus;

{$mode objfpc}{$H+}
{$modeswitch objectivec2}

interface

uses
  // Libs
  CocoaAll,
  MacOSAll,
  // RTL
  sysutils,
  // LCL
  Controls, Forms, Menus, Graphics, LCLType, LMessages, LCLProc, Classes,
  LCLMessageGlue,
  // Widgetset
  WSMenus, WSLCLClasses,
  // LCL Cocoa
  Cocoa_extra,
  CocoaPrivate, CocoaWSCommon, CocoaUtils, CocoaGDIObjects;

type

  IMenuItemCallback = interface(ICommonCallBack)
    procedure ItemSelected;
    function MenuItemTarget: TMenuItem;
  end;

  { TLCLMenuItemCallback }

  TLCLMenuItemCallback = class(TLCLCommonCallback, IMenuItemCallback)
  private
    FMenuItemTarget: TMenuItem;
  public
    constructor Create(AOwner: NSObject; AMenuItemTarget: TMenuItem); reintroduce;
    procedure ItemSelected;
    function MenuItemTarget: TMenuItem;
  end;

  TCocoaMenuItem = objcclass;

  { TCocoaMenu }

  TCocoaMenu = objcclass(NSMenu)
  private
    appleMenu: TCocoaMenuItem;
    attachedAppleMenu: Boolean;
  public
    procedure lclItemSelected(sender: id); message 'lclItemSelected:';
    procedure createAppleMenu(); message 'createAppleMenu';
    procedure overrideAppleMenu(AItem: TCocoaMenuItem); message 'overrideAppleMenu:';
    procedure attachAppleMenu(); message 'attachAppleMenu';
  end;

  { TCocoaMenuItem }

  TCocoaMenuItem = objcclass(NSMenuItem, NSMenuDelegateProtocol)
  public
    menuItemCallback: IMenuItemCallback;
    attachedAppleMenuItems: Boolean;
    FMenuItemTarget: TMenuItem;
    procedure UncheckSiblings(AIsChangingToChecked: Boolean = False); message 'UncheckSiblings:';
    function GetMenuItemHandle(): TMenuItem; message 'GetMenuItemHandle';
    procedure lclItemSelected(sender: id); message 'lclItemSelected:';
    function lclGetCallback: IMenuItemCallback; override;
    procedure lclClearCallback; override;
    procedure attachAppleMenuItems(); message 'attachAppleMenuItems';
    function isValidAppleMenu(): Boolean; message 'isValidAppleMenu';
    procedure menuNeedsUpdate(AMenu: NSMenu); message 'menuNeedsUpdate:';
  end;

  TCocoaMenuItem_HideApp = objcclass(NSMenuItem)
  public
    procedure lclItemSelected(sender: id); message 'lclItemSelected:';
  end;

  TCocoaMenuItem_HideOthers = objcclass(NSMenuItem)
  public
    procedure lclItemSelected(sender: id); message 'lclItemSelected:';
  end;

  TCocoaMenuItem_ShowAllApp = objcclass(NSMenuItem)
  public
    procedure lclItemSelected(sender: id); message 'lclItemSelected:';
  end;

  TCocoaMenuItem_Quit = objcclass(NSMenuItem)
  public
    procedure lclItemSelected(sender: id); message 'lclItemSelected:';
  end;

  { TCocoaWSMenuItem }

  TCocoaWSMenuItem = class(TWSMenuItem)
  private
    class procedure Do_SetCheck(const ANSMenuItem: NSMenuItem; const Checked: boolean);
    // used from the MenuMadness example
    class function NSMenuCheckmark: NSImage;
    class function NSMenuRadio: NSImage;
    class function isSeparator(const ACaption: AnsiString): Boolean;
  published
    class procedure AttachMenu(const AMenuItem: TMenuItem); override;
    class function  CreateHandle(const AMenuItem: TMenuItem): HMENU; override;
    class procedure DestroyHandle(const AMenuItem: TMenuItem); override;
    class procedure SetCaption(const AMenuItem: TMenuItem; const ACaption: string); override;
    class procedure SetShortCut(const AMenuItem: TMenuItem; const ShortCutK1, ShortCutK2: TShortCut); override;
    class procedure SetVisible(const AMenuItem: TMenuItem; const Visible: boolean); override;
    class function SetCheck(const AMenuItem: TMenuItem; const Checked: boolean): boolean; override;
    class function SetEnable(const AMenuItem: TMenuItem; const Enabled: boolean): boolean; override;
    class function SetRadioItem(const AMenuItem: TMenuItem; const RadioItem: boolean): boolean; override;
    //class function SetRightJustify(const AMenuItem: TMenuItem; const Justified: boolean): boolean; override;
    class procedure UpdateMenuIcon(const AMenuItem: TMenuItem; const HasIcon: Boolean; const AIcon: TBitmap); override;
  end;

  { TCocoaWSMenu }

  TCocoaWSMenu = class(TWSMenu)
  published
    class function CreateHandle(const AMenu: TMenu): HMENU; override;
  end;

  { TCocoaWSMainMenu }

  TCocoaWSMainMenu = class(TWSMainMenu)
  published
    class function CreateHandle(const AMenu: TMenu): HMENU; override;
  end;

  { TCocoaWSPopupMenu }

  TCocoaWSPopupMenu = class(TWSPopupMenu)
  published
    class procedure Popup(const APopupMenu: TPopupMenu; const X, Y: Integer); override;
  end;

procedure NSMenuItemSetBitmap(mn: NSMenuItem; bmp: TBitmap);

// the returned "Key" should not be released, as it's not memory owned
procedure ShortcutToKeyEquivalent(const AShortCut: TShortcut; out Key: NSString; out shiftKeyMask: NSUInteger);

procedure ToggleAppMenu(ALogicalEnabled: Boolean);

function AllocCocoaMenu(const atitle: string = ''): TCocoaMenu;
function LCLMenuItemInit(item: NSMenuItem; const atitle: string; ashortCut: TShortCut): id;
function LCLMenuItemInit(item: NSMenuItem; const atitle: string; VKKey: Word = 0; State: TShiftState = []): id;

implementation

uses
  CocoaInt;

function LCLMenuItemInit(item: NSMenuItem; const atitle: string; ashortCut: TShortCut): id;
var
  key   : NSString;
  mask  : NSUInteger;
begin
  ShortcutToKeyEquivalent(ashortCut, key, mask);

  Result := item.initWithTitle_action_keyEquivalent(
    ControlTitleToNSStr(Atitle),
    objcselector('lclItemSelected:'), // Selector is Hard-coded, that's why it's LCLMenuItemInit
    key);
  NSMenuItem(Result).setKeyEquivalentModifierMask(mask);
  NSMenuItem(Result).setTarget(Result);
end;

function LCLMenuItemInit(item: NSMenuItem; const atitle: string; VKKey: Word; State: TShiftState): id;
var
  key   : NSString;
  mask  : NSUInteger;
begin
  Result := LCLMenuItemInit(item, atitle, ShortCut(VKKey, State));
end;

function AllocCocoaMenu(const atitle: string = ''): TCocoaMenu;
begin
  Result := TCocoaMenu.alloc.initWithTitle(ControlTitleToNSStr(atitle));
  Result.setAutoenablesItems(false);
end;

{ TCocoaMenuItem_ShowAllApp }

procedure TCocoaMenuItem_ShowAllApp.lclItemSelected(sender: id);
begin
  NSApplication(NSApp).unhideAllApplications(sender);
end;

{ TLCLMenuItemCallback }

constructor TLCLMenuItemCallback.Create(AOwner: NSObject; AMenuItemTarget: TMenuItem);
begin
  Owner := AOwner;
  FMenuItemTarget := AMenuItemTarget;
end;

procedure TLCLMenuItemCallback.ItemSelected;
var
  Msg:TLMessage;
begin
  FillChar(Msg{%H-}, SizeOf(Msg), 0);
  Msg.msg := LM_ACTIVATE;
  // debugln('send LM_Activate');
  LCLMessageGlue.DeliverMessage(FMenuItemTarget,Msg);
end;

function TLCLMenuItemCallback.MenuItemTarget: TMenuItem;
begin
  Result:=FMenuItemTarget;
end;

{ TCocoaMenu }

procedure TCocoaMenu.lclItemSelected(sender:id);
begin

end;

// For when there is no menu item with title 
procedure TCocoaMenu.createAppleMenu();
var
  nskey, nstitle, nssubmeykey: NSString;
  lNSSubmenu: NSMenu;
begin
  // create the menu item
  nstitle := NSStringUtf8('');
  appleMenu := TCocoaMenuItem.alloc.initWithTitle_action_keyEquivalent(nstitle,
    objcselector('lclItemSelected:'), NSString.string_);
  nstitle.release;

  // add the submenu
  lNSSubmenu := NSMenu.alloc.initWithTitle(NSString.string_);
  appleMenu.setSubmenu(lNSSubmenu);

  appleMenu.attachAppleMenuItems();
end;

// For when there is a menu item with title 
procedure TCocoaMenu.overrideAppleMenu(AItem: TCocoaMenuItem);
begin
  if appleMenu <> nil then
  begin
    if indexOfItem(appleMenu) >= 0 then
      removeItem(appleMenu);
    appleMenu.release;
    appleMenu := nil;
  end;
  attachedAppleMenu := False;
  AItem.attachAppleMenuItems();
end;

procedure TCocoaMenu.attachAppleMenu();
begin
  if attachedAppleMenu then Exit;
  if appleMenu = nil then Exit;
  attachedAppleMenu := True;
  insertItem_atIndex(appleMenu, 0);
end;

{ TCocoaMenuITem }

procedure TCocoaMenuItem.UncheckSiblings(AIsChangingToChecked: Boolean);
var
  i: Integer;
  lMenuItem, lSibling, lParentMenu: TMenuItem;
  lSiblingHandle: NSMenuItem;
begin
  //lMenuItem := GetMenuItemHandle();
  lMenuItem := FMenuItemTarget;
  if lMenuItem = nil then Exit;
  if not lMenuItem.RadioItem then Exit;
  if (not AIsChangingToChecked) and (not lMenuItem.Checked) then Exit;
  lParentMenu := lMenuItem.Parent;
  if lParentMenu = nil then Exit;
  for i := 0 to lParentMenu.Count - 1 do
  begin
    lSibling := lParentMenu.Items[i];
    if lSibling = nil then Continue;
    if lSibling = lMenuItem then Continue;

    if lSibling.RadioItem and (lSibling.GroupIndex = lMenuItem.GroupIndex) and
      lSibling.HandleAllocated() then
    begin
      lSiblingHandle := NSMenuItem(lSibling.Handle);
      TCocoaWSMenuItem.Do_SetCheck(lSiblingHandle, False);
    end;
  end;
end;

function TCocoaMenuItem.GetMenuItemHandle(): TMenuItem;
begin
  Result := nil;
  if menuItemCallback = nil then Exit;
  Result := menuItemCallback.MenuItemTarget;
end;

procedure TCocoaMenuItem.lclItemSelected(sender:id);
begin
  menuItemCallback.ItemSelected;
  UncheckSiblings();
end;

function TCocoaMenuItem.lclGetCallback: IMenuItemCallback;
begin
  result:=menuItemCallback;
end;

procedure TCocoaMenuItem.lclClearCallback;
begin
  menuItemCallback := nil;
end;

procedure TCocoaMenuItem.attachAppleMenuItems();
var
  item    : NSMenuItem;
begin
  if attachedAppleMenuItems then Exit;
  if not hasSubmenu() then Exit;

  // Separator
  submenu.insertItem_atIndex(NSMenuItem.separatorItem, submenu.itemArray.count);

  // Services
  item := LCLMenuItemInit( TCocoaMenuItem.alloc, 'Services');
  item.setTarget(nil);
  item.setAction(nil);
  submenu.insertItem_atIndex(item, submenu.itemArray.count);
  item.setSubmenu(NSMenu.alloc.initWithTitle( NSSTR('Services')));
  NSApplication(NSApp).setServicesMenu(item.submenu);

  // Separator
  submenu.insertItem_atIndex(NSMenuItem.separatorItem, submenu.itemArray.count);

  // Hide App     Meta-H
  item := LCLMenuItemInit( TCocoaMenuItem_HideApp.alloc, 'Hide ' + Application.Title, VK_H, [ssMeta]);
  submenu.insertItem_atIndex(item, submenu.itemArray.count);

  // Hide Others  Meta-Alt-H
  item := LCLMenuItemInit( TCocoaMenuItem_HideOthers.alloc, 'Hide Others', VK_H, [ssMeta, ssAlt]);
  submenu.insertItem_atIndex(item, submenu.itemArray.count);

  // Show All
  item := LCLMenuItemInit( TCocoaMenuItem_ShowAllApp.alloc, 'Show All');
  submenu.insertItem_atIndex(item, submenu.itemArray.count);

  // Separator
  submenu.insertItem_atIndex(NSMenuItem.separatorItem, submenu.itemArray.count);

  // Quit   Meta-Q
  item := LCLMenuItemInit( TCocoaMenuItem_Quit.alloc, 'Quit '+Application.Title, VK_Q, [ssMeta]);
  submenu.insertItem_atIndex(item, submenu.itemArray.count);

  attachedAppleMenuItems := True;
end;

function TCocoaMenuItem.isValidAppleMenu(): Boolean;
begin
  Result := hasSubmenu() and (submenu() <> nil);
  Result := Result and ('' = NSStringToString(title));
end;

procedure TCocoaMenuItem.menuNeedsUpdate(AMenu: NSMenu);
begin
  if not Assigned(menuItemCallback) then Exit;
  menuItemCallback.ItemSelected;
end;

procedure TCocoaMenuItem_HideApp.lclItemSelected(sender: id);
begin
  // Applicaiton.Minimize, calls WidgetSet.AppMinimize;
  // which calls NSApplication.hide() anyway
  Application.Minimize;
end;

procedure TCocoaMenuItem_HideOthers.lclItemSelected(sender: id);
begin
  NSApplication(NSApp).hideOtherApplications(sender);
end;

procedure TCocoaMenuItem_Quit.lclItemSelected(sender: id);
begin
  // Should be used instead of Application.Terminate to allow events to be sent, see bug 32148
  Application.MainForm.Close;
end;

{ TCocoaWSMenu }

{------------------------------------------------------------------------------
  Method:  TCocoaWSMenu.CreateHandle
  Params:  AMenu - LCL menu
  Returns: Handle to the menu in Cocoa interface

  Creates new menu in Cocoa interface
 ------------------------------------------------------------------------------}
class function TCocoaWSMenu.CreateHandle(const AMenu: TMenu): HMENU;
begin
  //WriteLn(':>[TCocoaWSMenu.CreateHandle]');
  Result := HMENU(AllocCocoaMenu);
end;

{ TCocoaWSMainMenu }

class function TCocoaWSMainMenu.CreateHandle(const AMenu: TMenu): HMENU;
begin
  Result := HMENU(AllocCocoaMenu);
  TCocoaMenu(Result).createAppleMenu();
end;

{ TCocoaWSMenuItem }

class procedure TCocoaWSMenuItem.Do_SetCheck(const ANSMenuItem: NSMenuItem; const Checked: boolean);
const
  menustate : array [Boolean] of NSInteger = (NSOffState, NSOnState);
begin
  ANSMenuItem.setOnStateImage(NSMenuCheckmark);
  ANSMenuItem.setState( menustate[Checked] );
end;

// used from the MenuMadness example
class function TCocoaWSMenuItem.NSMenuCheckmark: NSImage;
begin
  Result:=NSImage.imageNamed(NSStringUtf8('NSMenuCheckmark'));
end;

class function TCocoaWSMenuItem.NSMenuRadio: NSImage;
begin
  Result:=NSImage.imageNamed(NSStringUtf8('NSMenuRadio'))
end;

class function TCocoaWSMenuItem.isSeparator(const ACaption: AnsiString): Boolean;
begin
  Result:=ACaption='-';
end;

{------------------------------------------------------------------------------
  Method:  TCocoaWSMenuItem.AttachMenu
  Params:  AMenuItem - LCL menu item

  Attaches menu item to its parent menu in Cocoa interface
 ------------------------------------------------------------------------------}
class procedure TCocoaWSMenuItem.AttachMenu(const AMenuItem: TMenuItem);
var
  ParObj  : NSObject;
  Parent  : TCocoaMenu;
  item    : NSMenuItem;
  MenuObj : NSObject;
  Menu    : NSMenu;
begin
  if not Assigned(AMenuItem) or (AMenuItem.Handle=0) or not Assigned(AMenuItem.Parent) or (AMenuItem.Parent.Handle=0) then Exit;
  ParObj:=NSObject(AMenuItem.Parent.Handle);
  item:=NSMenuItem(AMenuItem.Handle);

  if ParObj.isKindOfClass(NSMenuItem) then
  begin
    if not NSMenuItem(ParObj).hasSubmenu then
    begin
      Parent := AllocCocoaMenu(AMenuItem.Parent.Caption);
      Parent.setDelegate(TCocoaMenuItem(ParObj));
      NSMenuItem(ParObj).setSubmenu(Parent);
    end
    else
      Parent:=TCocoaMenu(NSMenuItem(ParObj).submenu);
  end else if ParObj.isKindOfClass(NSMenu) then
    Parent:=TCocoaMenu(ParObj)
  else
    Exit;

  item := nil;
  MenuObj := NSObject(AMenuItem.Handle);
  if MenuObj.isKindOfClass(NSMenuItem) then
    item := NSMenuItem(MenuObj)
  else if MenuObj.isKindOfClass(NSMenu) then
  begin
    Menu := NSMenu(MenuObj);
    item := NSMenuItem(NSMenuItem.alloc).initWithTitle_action_keyEquivalent(
      ControlTitleToNSStr(AMenuItem.Caption), nil, NSString.string_ );
    item.setSubmenu( Menu );
  end;

  if Assigned(item) then
    Parent.insertItem_atIndex(NSMenuItem(item), AMenuItem.MenuVisibleIndex)
end;

{------------------------------------------------------------------------------
  Method:  TCocoaWSMenuItem.CreateHandle
  Params:  AMenuItem - LCL menu item
  Returns: Handle to the menu item in Cocoa interface

  Creates new menu item in Cocoa interface
 ------------------------------------------------------------------------------}
class function TCocoaWSMenuItem.CreateHandle(const AMenuItem: TMenuItem): HMENU;
var
  item    : NSMenuItem;
  ANSMenu : NSMenu;
begin
  if not Assigned(AMenuItem) then
  begin
    Result:=0;
    Exit;
  end;

  // A handle of TMenu.fItems (TMenuItem) could be recreated.
  // in this case LCL calls TCocoaWSMenuItem.CreateHandle
  // instead of the proper owner.
  if (AMenuItem.Owner is TMainMenu) and (TMainMenu(AMenuItem.Owner).Items = AMenuItem) then begin
    Result:=TCocoaWSMainMenu.CreateHandle(TMenu(AMenuItem.Owner));
    Exit;
  end else if (AMenuItem.Owner is TMenu) and (TMenu(AMenuItem.Owner).Items = AMenuItem) then begin
    Result:=TCocoaWSMenu.CreateHandle(TMenu(AMenuItem.Owner));
    Exit;
  end;

  if AMenuItem.Caption = '-' then
  begin
    item := NSMenuItem.separatorItem;
  end
  else
  begin
    item := LCLMenuItemInit(TCocoaMenuItem.alloc, AMenuItem.Caption, AMenuItem.ShortCut);
    TCocoaMenuItem(item).FMenuItemTarget := AMenuItem;

    if AMenuItem.IsInMenuBar then
    begin
      ANSMenu := AllocCocoaMenu(AMenuItem.Caption);
      ANSMenu.setDelegate(TCocoaMenuItem(item));
      item.setSubmenu(ANSMenu);
    end;

    TCocoaMenuItem(item).menuItemCallback:=TLCLMenuItemCallback.Create(item, AMenuItem);

    // initial set of properties
    {$ifdef BOOLFIX}
    item.setEnabled_(Ord(AMenuItem.Enabled));
    {$else}
    item.setEnabled(AMenuItem.Enabled);
    {$endif}
    Do_SetCheck(item, AMenuItem.Checked);

    if AMenuItem.HasIcon and ((AMenuItem.ImageIndex>=0) or (AMenuItem.HasBitmap)) then
      NSMenuItemSetBitmap(item, AMenuItem.Bitmap);
  end;

  Result:=HMENU(item);
end;

{------------------------------------------------------------------------------
  Method:  TCocoaWSMenuItem.DestroyHandle
  Params:  AMenuItem - LCL menu item

  Destroys menu item in Cocoa interface
 ------------------------------------------------------------------------------}
class procedure TCocoaWSMenuItem.DestroyHandle(const AMenuItem: TMenuItem);
var
  callback: IMenuItemCallback;
  callbackObject: TObject;
  item    : NSObject;
  parItem : NSObject;
begin
  if AMenuItem.Caption <> '-' then
    begin
    item:=NSObject(AMenuItem.Handle);
    if item.isKindOfClass_(TCocoaMenuItem) then
      begin
      callback := TCocoaMenuItem(item).lclGetCallback;
      if Assigned(callback) then
        begin
        callbackObject := callback.GetCallbackObject;
        callback := nil;
        TCocoaMenuItem(item).lclClearCallback;
        callbackObject.Free;
        end;
      parItem := TCocoaMenuItem(Item).parentItem;
      if assigned(parItem) and parItem.isKindOfClass_(NSMenuItem) then
        NSMenuItem(paritem).submenu.removeItem(NSMenuItem(item));
      //Item.Release;
      AMenuItem.Handle := 0;
      end
    end;
end;

{------------------------------------------------------------------------------
  Method:  TCocoaWSMenuItem.SetCaption
  Params:  AMenuItem - LCL menu item
           ACaption  - Menu item caption

  Sets the caption of menu item in Cocoa interface
 ------------------------------------------------------------------------------}
class procedure TCocoaWSMenuItem.SetCaption(const AMenuItem: TMenuItem; const ACaption: string);
var
  ns : NSString;
  s: string;
begin
  if not Assigned(AMenuItem) or (AMenuItem.Handle=0) then Exit;
  s := ACaption;
  DeleteAmpersands(s);
  ns:=NSStringUtf8(s);
  NSMenuItem(AMenuItem.Handle).setTitle(ns);
  if NSMenuItem(AMenuItem.Handle).hasSubmenu then
    NSMenuItem(AMenuItem.Handle).submenu.setTitle(ns);
  ns.release;
end;

{------------------------------------------------------------------------------
  Method:  TCocoaWSMenuItem.SetShortCut
  Params:  AMenuItem   - LCL menu item
           ShortCutK1 and ShortCutK2 - New shortcut key1 and key2

  Sets the shortcut of menu item in Cocoa interface
 ------------------------------------------------------------------------------}
class procedure TCocoaWSMenuItem.SetShortCut(const AMenuItem: TMenuItem;
  const ShortCutK1, ShortCutK2: TShortCut);
var
  ShiftState: NSUInteger;
  ns: NSString;
begin
  ShortcutToKeyEquivalent(ShortCutK1, ns, ShiftState);
  TCocoaMenuItem(AMenuItem.Handle).setKeyEquivalentModifierMask(ShiftState);
  TCocoaMenuItem(AMenuItem.Handle).setKeyEquivalent(ns);
end;

{------------------------------------------------------------------------------
  Method:  TCocoaWSMenuItem.SetVisible
  Params:  AMenuItem - LCL menu item
           Visible   - Menu item visibility

  Sets the visibility of menu item in Cocoa interface
 ------------------------------------------------------------------------------}
class procedure TCocoaWSMenuItem.SetVisible(const AMenuItem: TMenuItem;
  const Visible: boolean);
begin
  if not Assigned(AMenuItem) or (AMenuItem.Handle=0) then Exit;
  {$ifdef BOOLFIX}
  NSMenuItem(AMenuItem.Handle).setHidden_( Ord(not Visible) );
  {$else}
  NSMenuItem(AMenuItem.Handle).setHidden( not Visible );
  {$endif}
end;

{------------------------------------------------------------------------------
  Method:  TCocoaWSMenuItem.SetCheck
  Params:  AMenuItem - LCL menu item
           Checked   - Menu item checked
  Returns: If the function succeeds

  Sets the check of menu item in Cocoa interface
 ------------------------------------------------------------------------------}
class function TCocoaWSMenuItem.SetCheck(const AMenuItem: TMenuItem;
  const Checked: boolean): boolean;
var
  lHandle: NSMenuItem;
  lCocoaHandle: TCocoaMenuItem absolute lHandle;
begin
  Result := Assigned(AMenuItem) and AMenuItem.HandleAllocated() and (AMenuItem.Handle<>0);
  if not Result then Exit;
  lHandle := NSMenuItem(AMenuItem.Handle);
  Result := Result and lHandle.isKindOfClass_(TCocoaMenuItem);
  if not Result then Exit;
  TCocoaWSMenuItem.Do_SetCheck(lHandle, Checked);
  lCocoaHandle.UncheckSiblings(True);
end;

{------------------------------------------------------------------------------
  Method:  TCocoaWSMenuItem.SetEnable
  Params:  AMenuItem - LCL menu item
           Enabled   - Menu item enabled
  Returns: If the function succeeds

  Sets the enabled of menu item in Cocoa interface
 ------------------------------------------------------------------------------}
class function TCocoaWSMenuItem.SetEnable(const AMenuItem: TMenuItem;
  const Enabled: boolean): boolean;
begin
  Result:=Assigned(AMenuItem) and (AMenuItem.Handle<>0);
  if not Result then Exit;
  {$ifdef BOOLFIX}
  NSMenuItem(AMenuItem.Handle).setEnabled_( Ord(Enabled) );
  {$else}
  NSMenuItem(AMenuItem.Handle).setEnabled( Enabled );
  {$endif}
end;

{------------------------------------------------------------------------------
  Method:  TCocoaWSMenuItem.SetRadioItem
  Params:  AMenuItem - LCL menu item
           RadioItem - Menu item has radio
  Returns: If the function succeeds

  Sets the radio behaviour of menu item in Cocoa interface
 ------------------------------------------------------------------------------}
class function TCocoaWSMenuItem.SetRadioItem(const AMenuItem: TMenuItem;
  const RadioItem: boolean): boolean;
const
  menustate : array [Boolean] of NSInteger = (NSOffState, NSOnState);
begin
  Result:=Assigned(AMenuItem) and (AMenuItem.Handle<>0);
  if not Result then Exit;
  //todo: disable relative radio items
  NSMenuItem(AMenuItem.Handle).setOnStateImage( NSMenuRadio );
  NSMenuItem(AMenuItem.Handle).setState( menustate[RadioItem] );
end;

procedure NSMenuItemSetBitmap(mn: NSMenuItem; bmp: TBitmap);
begin
  if not Assigned(mn) then Exit;
  if not Assigned(bmp) or (bmp.Handle = 0) then
    mn.setImage(nil)
  else
    mn.setImage(TCocoaBitmap(bmp.Handle).Image);
end;

class procedure TCocoaWSMenuItem.UpdateMenuIcon(const AMenuItem: TMenuItem;
  const HasIcon: Boolean; const AIcon: TBitmap);
var
  mn : NSMenuItem;
begin
  if not Assigned(AMenuItem) or (AMenuItem.Handle=0) then Exit;

  if NSObject(AMenuItem.Handle).isKindOfClass(NSMenuItem) then
    NSMenuItemSetBitmap( NSMenuItem(AMenuItem.Handle), AIcon);
end;

{ TCocoaWSPopupMenu }

function LCLCoordsToCocoa(AControl: TControl; X, Y: Integer): NSPoint;
begin
  Result.x := X;
  Result.y := NSScreen.mainScreen.frame.size.height - Y;
  if AControl <> nil then Result.y := Result.y - AControl.Height;
end;

{------------------------------------------------------------------------------
  Method:  TCocoaWSPopupMenu.Popup
  Params:  APopupMenu - LCL popup menu
           X, Y       - Screen coordinates to popup

  Popups menu in Cocoa interface
 ------------------------------------------------------------------------------}
class procedure TCocoaWSPopupMenu.Popup(const APopupMenu: TPopupMenu; const X,
  Y: Integer);
var
  res : Boolean;
  mnu : NSMenuItem;
begin
  if Assigned(APopupMenu) and (APopupMenu.Handle<>0) then
  begin
    // old method which doesn't consider position but supports 10.0+ (useless since we target 10.6+)
    {w:=NSApp.keyWindow;
    if Assigned(w) then
    begin
      NSMenu.popUpContextMenu_withEvent_forView( TCocoaMenu(APopupMenu.Handle),
        NSApp.currentEvent, NSView(w.contentView));
    end;}

    // New method for 10.6+
    res := TCocoaMenu(APopupMenu.Handle).popUpMenuPositioningItem_atLocation_inView(
      nil, LCLCoordsToCocoa(nil, X, Y), nil);

    // for whatever reason a context menu will not fire the "action"
    // of the specified target. Thus we're doing it here manually. :(
    // It seems a typical behaviour for all versions of macOS
    // todo: find out why. (calling runModalSession makes no difference)
    if Assigned(CocoaWidgetSet.Modals) and (CocoaWidgetSet.Modals.Count>0) then
    begin
      mnu := TCocoaMenu(APopupMenu.Handle).highlightedItem;
      if res and Assigned(mnu) then
      begin
        if mnu.respondsToSelector(ObjCSelector('lclItemSelected:')) then
          TCocoaMenuItem(mnu).lclItemSelected(mnu);
      end;
    end;

    APopupMenu.Close; // notify LCL popup menu
  end;
end;

procedure ShortcutToKeyEquivalent(const AShortCut: TShortcut; out Key: NSString; out shiftKeyMask: NSUInteger);
var
  w: word;
  s: TShiftState;
begin
  ShortCutToKey(AShortCut, w, s);
  key := VirtualKeyCodeToMacString(w);
  shiftKeyMask := 0;
  if ssShift in s then
    ShiftKeyMask := ShiftKeyMask + NSShiftKeyMask;
  if ssAlt in s then
    ShiftKeyMask := ShiftKeyMask + NSAlternateKeyMask;
  if ssCtrl in s then
    ShiftKeyMask := ShiftKeyMask + NSControlKeyMask;
  if ssMeta in s then
    ShiftKeyMask := ShiftKeyMask + NSCommandKeyMask;
end;

procedure ToggleAppNSMenu(mn: NSMenu; ALogicalEnabled: Boolean);
var
  it  : NSMenuItem;
  obj : NSObject;
  enb : Boolean;
begin
  if not Assigned(mn) then Exit;
  for obj in mn.itemArray do begin
    if not obj.isKindOfClass(NSMenuItem) then continue;
    it := NSMenuItem(obj);
    enb := ALogicalEnabled;
    if enb and (it.isKindOfClass(TCocoaMenuItem)) then
    begin
      enb := not Assigned(TCocoaMenuItem(it).FMenuItemTarget)
         or ( TCocoaMenuItem(it).FMenuItemTarget.Enabled );
    end;
    {$ifdef BOOLFIX}
    it.setEnabled_( Ord(enb));
    {$else}
    it.setEnabled(enb);
    {$endif}
    if (it.hasSubmenu) then
    begin
      ToggleAppNSMenu(it.submenu, ALogicalEnabled);
    end;
  end;
end;

procedure ToggleAppMenu(ALogicalEnabled: Boolean);
begin
  ToggleAppNSMenu( NSApplication(NSApp).mainMenu, ALogicalEnabled );
end;

end.
