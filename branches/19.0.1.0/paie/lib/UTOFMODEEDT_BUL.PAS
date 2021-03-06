{***********UNITE*************************************************
Auteur  ...... :
Cr�� le ...... : 07/03/2007
Modifi� le ... :   /  /
Description .. : Source TOF de la FICHE : UTOFMODEEDT_BUL ()
Mots clefs ... : TOF;UTOFMODEEDT_BUL
*****************************************************************}
Unit UTOFMODEEDT_BUL ;

Interface

Uses StdCtrls,
     Controls,
     Classes,
{$IFNDEF EAGLCLIENT}
     db, 
     {$IFNDEF DBXPRESS} dbtables, {$ELSE} uDbxDataSet, {$ENDIF} 
     mul, 
{$else}
     eMul, 
     uTob, 
{$ENDIF}
     forms, 
     sysutils,
     ComCtrls,
     HCtrls,
     HEnt1,
     HMsgBox,
     UTOF ;

Type
  TOF_UTOFMODEEDT_BUL = Class (TOF)
    procedure OnArgument (S : String ) ; override ;
    procedure OnClose                  ; override ;
    procedure OnUpdate                 ; override ;
  end ;

Implementation

uses Pgoutils;

procedure TOF_UTOFMODEEDT_BUL.OnArgument (S : String ) ;
var
  EMode:THValComboBox;
  Plus:String;
begin
  Inherited ;

  PGModeEdition := '';

  EMode := THValComboBox(GetControl('MODEEDITION'));

  // Adapter les valeurs de la combo en fonction du droit d'acc�s aux menus d'�ditions du bulletin
  if not JaiLeDroitTag(42313) or (S = 'SAISBUL') then
    Plus := ' AND CO_CODE <> "ORI"';
  if not JaiLeDroitTag(42314) then
    Plus := Plus + ' AND CO_CODE <> "DUP"';
  if not JaiLeDroitTag(42316) then
    Plus := Plus + ' AND CO_CODE <> "SPE"';

  if Plus <> '' then
    EMode.Plus := Plus;
    
  if JaiLeDroitTag(42314) then
    EMode.Value := 'DUP'  // Initialiser � Duplicata
  else
    EMode.Value := 'SPE'; // Initialiser � Specimen
end ;

procedure TOF_UTOFMODEEDT_BUL.OnClose ;
begin
  Inherited ;
end ;

procedure TOF_UTOFMODEEDT_BUL.OnUpdate;
var
  EMode:THValComboBox;
  Texte:String;
begin
  Inherited ;
  EMode := THValComboBox(GetControl('MODEEDITION'));
  if (EMode <> nil) then
  begin
    if EMode.Value = '' then
    begin
      LastErrorMsg := TraduireMemoire('Vous devez renseigner une valeur pour le mode d''�dition');
      LastError := 1;
      exit;
    end
    else
      //V�rifier si l'utilisateur � le droit de lancer cette option
      if (EMode.Value = 'ORI') then
        if not JaiLeDroitTag(42313) then
        begin
          LastErrorMsg := TraduireMemoire('Vous n''�tes pas autoris� � lancer une �dition d''originaux');
          LastError := 2;
          exit;
        end;
      if (EMode.Value = 'DUP') then
        if not JaiLeDroitTag(42314) then
        begin
          LastErrorMsg := TraduireMemoire('Vous n''�tes pas autoris� � lancer une �dition de duplicatas');
          LastError := 3;
          exit;
        end;
      if (EMode.Value = 'SPE') then
        if not JaiLeDroitTag(42316) then
        begin
          LastErrorMsg := TraduireMemoire('Vous n''�tes pas autoris� � lancer une �dition de specimens');
          LastError := 4;
          exit;
        end;
      // A priori l'utilisateur � au moins le droit d'�diter un duplicata
      Texte := EMode.text;
      PGModeEdition := UpperCase(Texte);
      Ecran.Close;
  end;
end ;

Initialization
  registerclasses ( [ TOF_UTOFMODEEDT_BUL ] ) ;
end.
