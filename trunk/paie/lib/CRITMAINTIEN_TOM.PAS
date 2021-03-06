{***********UNITE*************************************************
Auteur  ...... : PAIE- MF
Cr�� le ...... : 20/07/2004
Modifi� le ... : 27/07/2004
Description .. : Source TOM de la TABLE : CRITMAINTIEN
Suite ........ : (CRITMAINTIEN)
Suite ........ : Param�trage des diverses m�thodes de maintien. D�finition 
Suite ........ : des crit�res d'application (convention, anciennet�,  
Suite ........ : cat�gorie...), de la carence, du taux � appliquer et de la
Suite ........ : dur�e d'application des m�todes de calcul (r�gles)
Mots clefs ... : PAIE;TOM;CRITMAINTIEN; MAINTIEN
*****************************************************************}
{
PT1 30/11/2004 MF V_60 Correction traitement maintien qd champ cat�gorie renseign�.
PT2 20/12/2004 PH V_60 Erreur SQL DB2
PT3 24/02/2005 MF V_60 Mise au point CWAS : le champ PCM_CUMULPAIE est renseign�
                       par d�faut � NET
PT4 15/02/2006 MF V_65 FQ 12094 : affichage tablette quand champ crit�re de maintien
                       = Coefficient
PT5 24/02/2006 MF V_65 idem FQ 12094 : Pour qualification, indice et niveau
PT6 16/03/2006 MF V_65 FQ 12968 : PCM_VALCATEG remplac� par PCM_VALCATEGORIE
PT7 19/06/2007 MF V_72 FQ 14407 : dans le cas de la tablette PGLIBCOEFFICIENT on
                        ne modifie plus la propri�t� PLUS (voir FQ 15588)
}
Unit CRITMAINTIEN_TOM ;

Interface

Uses
// unused    StdCtrls, 
     Controls, 
     Classes, 
{$IFNDEF EAGLCLIENT}
     db, 
     {$IFNDEF DBXPRESS} dbTables, {$ELSE} uDbxDataSet, {$ENDIF}
     Fe_Main,
     Fiche,
     HDB,
//unused     FichList,
{$else}
     eFiche, 
//unused     eFichList,
     Maineagl,
{$ENDIF}
     EntPaie,
//unused     forms,
     sysutils, 
//unused     ComCtrls,
     HCtrls, 
     HEnt1, 
     HMsgBox,
     HTB97,
     PgOutils,
//unused     P5Def,
     UTOM,
     PgOutils2,
     UTob;
//     uTobDebug ;

Type
  TOM_CRITMAINTIEN = Class (TOM)
    private
    CEG, STD, DOS                       : Boolean;
    State                               : string;
    Categ                               : string;
    LibCateg                            : string; //PT1
    Duplique, Modifie, RegleAssociee    : boolean;
    AncValCod,AncConv,AncBorneFin : string;

    procedure BGESTIONASSClick (Sender: TObject);
    procedure DupliquerTableMaintien(Sender: TObject);

    public
    procedure OnNewRecord                ; override ;
    procedure OnDeleteRecord             ; override ;
    procedure OnUpdateRecord             ; override ;
    procedure OnAfterUpdateRecord        ; override ;
    procedure OnLoadRecord               ; override ;
    procedure OnChangeField ( F: TField) ; override ;
    procedure OnArgument ( S: String )   ; override ;
    procedure OnClose                    ; override ;
    procedure OnCancelRecord             ; override ;
    end ;

Implementation

{***********A.G.L.Priv�.*****************************************
Auteur  ...... : PAIE- MF
Cr�� le ...... : 27/07/2004
Modifi� le ... : 27/07/2004
Description .. : proc�dure OnNewRecord
Suite ........ : initialisation des champs de la fiche.
Mots clefs ... : PAIE;MAINTIEN
*****************************************************************}
procedure TOM_CRITMAINTIEN.OnNewRecord ;
begin
  Inherited ;
  SetField('PCM_CODEMAINT','');
  if (CEG = TRUE) then
    SetField('PCM_PREDEFINI', 'CEG')
  else
    SetField('PCM_PREDEFINI', 'DOS');
  SetField('PCM_NODOSSIER','');
  SetField('PCM_CONVENTION','');
  SetField('PCM_BORNEDEBANC',0);
  SetField('PCM_BORNEFINANC',0);
  SetField('PCM_LIBELLE','');
  SetField('PCM_TYPEABS','');
  SetField('PCM_VALCATEG','');
  SetField('PCM_MAINTIENNET','-');
  SetField('PCM_RUBIJSSNETTE','');
  SetField('PCM_RUBIJSSBRUTE','');
  SetField('PCM_RUBMAINTIEN','');
  SetField('PCM_CUMULPAIE','');
  SetField('PCM_VALCATEGORIE','');     // PT6

  State := 'ACTION=CREATION';
end ;

{***********A.G.L.Priv�.*****************************************
Auteur  ...... : PAIE- MF
Cr�� le ...... : 27/07/2004
Modifi� le ... : 27/07/2004
Description .. : proc�dure OnDeleteRecord
Suite ........ : Quand on supprime un crit�re (une table), il faut supprimer 
Suite ........ : les r�gles associ�es
Mots clefs ... : PAIE;MAINTIEN
*****************************************************************}
procedure TOM_CRITMAINTIEN.OnDeleteRecord ;
begin
  Inherited ;
  ExecuteSQL('DELETE FROM REGLESMAINTIEN WHERE '+
             'PAM_PREDEFINI ="'+
             GetField('PCM_PREDEFINI')+'"'+
             ' AND PAM_CODEMAINT="'+
             GetField('PCM_CODEMAINT')+'"'+
             ' AND PAM_NODOSSIER="'+
             GetField('PCM_NODOSSIER')+'"'+
             ' AND PAM_BORNEFINANC='+ // PT2
             IntToStr(GetField('PCM_BORNEFINANC'))+ // PT2
             ' AND PAM_CONVENTION="'+
             GetField('PCM_CONVENTION')+'"');
end ;

{***********A.G.L.Priv�.*****************************************
Auteur  ...... : PAIE- MF
Cr�� le ...... : 27/07/2004
Modifi� le ... : 27/07/2004
Description .. : Proc�dure OnUpdateRecord
Suite ........ : Lors de la validation contr�le du param�trage des rubriques 
Suite ........ : de paie utilis�es pour le maintien et les IJSS
Suite ........ :
Mots clefs ... : PAIE;MAINTIEN; IJSS
*****************************************************************}
procedure TOM_CRITMAINTIEN.OnUpdateRecord ;
var
  Q                                    : TQuery;
  st,PredExist                                   : string;
  T_regles,T,TOB_GestAssoc                                      : TOB;
  i                                                             : integer;

begin
  Inherited ;
  if (GetField('PCM_CONVENTION') = '') then
    SetField('PCM_CONVENTION','000');
  if (VH_PAie.PGGestIJSS = True) and  (GetField('PCM_RUBIJSSNETTE') = '') then
  begin
      SetFocusControl('PCM_RUBIJSSNETTE');
      LastErrorMsg:='La rubrique IJSS nette n''a pas �t� renseign�e';
      LastError := 1;
  end;

  if (VH_PAie.PGGestIJSS = True) and  (GetField('PCM_RUBIJSSBRUTE') = '') then
  begin
      SetFocusControl('PCM_RUBIJSSBRUTE');
      LastErrorMsg:='La rubrique IJSS brute n''a pas �t� renseign�e';
      LastError := 1;
  end;
  if (VH_PAie.PGMaintien = True) and  (GetField('PCM_RUBMAINTIEN') = '') then
  begin
      SetFocusControl('PCM_RUBMAINTIEN');
      LastErrorMsg:='La rubrique de maintien n''a pas �t� renseign�e';
      LastError := 1;
  end;

  if duplique then
  begin
       // Duplication des REGLESMAINTIEN
     PredExist := '';
     st := 'SELECT * FROM REGLESMAINTIEN '+
           'WHERE ##PAM_PREDEFINI## PAM_CODEMAINT="' + AncValCod + '"'+
           ' AND PAM_CONVENTION="'+ AncConv + '"'+
           ' AND PAM_BORNEFINANC='+ AncBorneFin; // PT2

     Q := OpenSql(st, TRUE);
     if not Q.eof then
     begin
       TOB_GestAssoc := TOB.Create('Les R�gles', nil, -1);
       TOB_GestAssoc.LoadDetailDB('REGLESMAINTIEN', '', '', Q, FALSE);

       //Suppression des �lements non conserv�s pour ne pas cr�er de doublon
       if TOB_GestAssoc.FindFirst(['PAM_PREDEFINI'], ['CEG'], False) <> nil then
         PredExist := 'CEG';
       if TOB_GestAssoc.FindFirst(['PAM_PREDEFINI'], ['STD'], False) <> nil then
         PredExist := PredExist + ';STD';
       if TOB_GestAssoc.FindFirst(['PAM_PREDEFINI'], ['DOS'], False) <> nil then
         PredExist := PredExist + ';DOS';

       T := TOB_GestAssoc.FindFirst([''], [''], False);
       while T <> nil do
       begin
         if (PGCodePredefini <> 'CEG') and
            (T.GetValue('PAM_PREDEFINI') <> PGCodePredefini) and
            (Pos(PGCodePredefini, PredExist) > 0) then
           T.Free;
         if (Pos('DOS', PredExist) = 0) and (PGCodePredefini = 'DOS') and
            (Pos('CEG', PredExist) > 0) and (Pos('STD', PredExist) > 0) then
           if T.GetValue('PAM_PREDEFINI') = 'CEG' then
             T.Free;
         T := TOB_GestAssoc.FindNext([''], [''], False);
       end;

       try
         BeginTrans;

         // Duplication des �l�ments restants
         T_Regles := TOB.Create('Les R�gles dupliqu�es', nil, -1);
         for i := 0 to TOB_GestAssoc.Detail.Count - 1 do
         begin
           T := TOB_GestAssoc.Detail[i];
           T.PutValue('PAM_CODEMAINT', PGCodeDupliquer);
           T.PutValue('PAM_PREDEFINI', PGCodePredefini);
           if PGCodePredefini = 'DOS' then
             T.PutValue('PAM_NODOSSIER', PgRendNoDossier)
           else
             T.PutValue('PAM_NODOSSIER', '000000');
           T.PutValue('PAM_CONVENTION',Getfield('PCM_CONVENTION'));
           T.PutValue('PAM_BORNEFINANC',Getfield('PCM_BORNEFINANC'));
         end;

         T_Regles.Dupliquer(Tob_GestAssoc, TRUE, TRUE, FALSE);
         T_Regles.InsertDB(nil, False);

         FreeAndNil(TOB_GestAssoc);
         FreeAndNil(T_Regles);

         CommitTrans;
       except
        Rollback;
        PGIBox('Une erreur est survenue lors de la duplication '+
               'des �l�ments associ�s.', Ecran.caption);
       end;
     end;
     ferme(Q);
     duplique := false;
  end;

  if not RegleAssociee then
  begin
    st := 'SELECT PAM_CODEMAINT FROM REGLESMAINTIEN WHERE '+
             'PAM_PREDEFINI ="'+
             GetField('PCM_PREDEFINI')+'"'+
             ' AND PAM_CODEMAINT="'+
             GetField('PCM_CODEMAINT')+'"'+
             ' AND PAM_NODOSSIER="'+
             GetField('PCM_NODOSSIER')+'"'+
             ' AND PAM_BORNEFINANC='+ // PT2
             IntToStr(GetField('PCM_BORNEFINANC'))+ // PT2
             ' AND PAM_CONVENTION="'+
             GetField('PCM_CONVENTION')+'"';
    Q := OpenSQL(st, TRUE);
    if  Q.EOF then
    begin
      SetFocusControl('PCM_CODEMAINT');
      LastErrorMsg:='Vous n''avez pas saisi de r�gle associ�e';
      LastError := 1;
    end;
    ferme (Q);
  end
  else
    LastError := 1;
    
  Modifie := True;

  AncValCod := '';
  AncConv := '';
  AncBorneFin := '';
end ;

procedure TOM_CRITMAINTIEN.OnAfterUpdateRecord ;
begin
  Inherited ;
end ;



{***********A.G.L.Priv�.*****************************************
Auteur  ...... : PAIE- MF
Cr�� le ...... : 27/07/2004
Modifi� le ... : 27/07/2004
Description .. : proc�dure OnLoadRecord
Suite ........ : chargement du contenu de la fiche. Traitement du pr�d�fini, 
Suite ........ : de l'acc�s ou non aux champs de la cl� en fonction du
Suite ........ : traitement (cr�ation ou modification)
Mots clefs ... : PAIE; MAINTIEN
*****************************************************************}
procedure TOM_CRITMAINTIEN.OnLoadRecord ;
var
  Q                                             : TQuery;
// d PT4
{$IFNDEF EAGLCLIENT}
  ChampLib                                      : THDBMultiValComboBox;
{$ELSE}
  ChampLib                                      : THMultiValComboBox;
{$ENDIF}
// f PT4
begin
  Inherited ;

 if (Getfield('PCM_PREDEFINI') = 'CEG') then
  begin
    PaieLectureSeule(TFFiche(Ecran), (CEG = False));
    SetControlEnabled('BDelete', CEG);
    SetControlProperty('Bdelete','Enabled',CEG);
  end;

  if (Getfield('PCM_PREDEFINI') = 'STD') then
  begin
    PaieLectureSeule(TFFiche(Ecran), (STD = False));
    SetControlEnabled('BDelete', STD);
    SetControlProperty('Bdelete','Enabled',STD);
  end;

  if (Getfield('PCM_PREDEFINI') = 'DOS') then
  begin
    PaieLectureSeule(TFFiche(Ecran), False);
    SetControlEnabled('BDelete', DOS);
    SetControlProperty('Bdelete','Enabled',DOS);
  end;

  if (VH_Paie.PGCritMaintien = '') then
  // le param�tre soci�t� "Champ crit�re de maintien" n'est pas renseign�
  begin
    SetControlEnabled('PCM_VALCATEGORIE',False);      // PT6
    SetControlVisible('PCM_VALCATEGORIE',False);      // PT6
    SetControlVisible('TPCM_VALCATEGORIE',False);     // PT6
  end
  else
  // le param�tre soci�t� "Champ crit�re de maintien" est renseign�
  begin
    Q := OpenSQL('SELECT PAI_LIENASSOC,PAI_LIBELLE FROM PAIEPARIM WHERE PAI_IDENT = "'+ //PT1
               VH_Paie.PGCritMaintien+'"' , TRUE);
    if not Q.EOF then
    begin
      Categ := Q.Fields[0].AsString;
      LibCateg := Q.Fields[1].AsString; //PT1
      setControlProperty('PCM_VALCATEGORIE','DataType',Categ);    // PT6
      setControlProperty('TPCM_VALCATEGORIE','Caption',Q.Fields[1].AsString); //PT1 PT6
// d PT4
      if (Categ = 'PGLIBCOEFFICIENT') then
      // Champ crit�re de maintien = Coefficient
      begin
{$IFNDEF EAGLCLIENT}
         ChampLib := THDBMultiValComboBox(GetControl('PCM_VALCATEGORIE')); // PT6
{$ELSE}
         ChampLib := THMultiValComboBox(GetControl('PCM_VALCATEGORIE')); //PT6
{$ENDIF}
         if (GetField('PCM_CONVENTION') <> '') and
            (Getfield('PCM_CONVENTION') <> '000') then
         // on limite la tablette aux coefficients de la convention collective choisie
         begin
              if ChampLib <> nil then
// d PT7
//               ChampLib.Plus := ' PMI_NATURE = "COE" AND '+
                 ChampLib.Plus := ' AND '+
                                  '(PMI_CONVENTION = "' +
                                    GetField('PCM_CONVENTION')+
                                    '")';
         end;
{
         else
         begin
         // tablette de tous les coefficients de toutes les conventions du dossier
             if ChampLib <> nil then
                 ChampLib.Plus := ' AND PMI_NATURE="COE" ';
         end }
// f PT7
      end
//d PT5
      else
      if (Categ = 'PGLIBQUALIFICATION') then
      // Champ crit�re de maintien = Qualification
      begin
{$IFNDEF EAGLCLIENT}
         ChampLib := THDBMultiValComboBox(GetControl('PCM_VALCATEGORIE')); // PT6
{$ELSE}
         ChampLib := THMultiValComboBox(GetControl('PCM_VALCATEGORIE')); // PT6
{$ENDIF}
         if (GetField('PCM_CONVENTION') <> '') and
            (Getfield('PCM_CONVENTION') <> '000') then
         // on limite la tablette aux coefficients de la convention collective choisie
         begin
              if ChampLib <> nil then
                 ChampLib.Plus := ' AND PMI_CONVENTION = "' +
                                    GetField('PCM_CONVENTION')+
                                    '"';
         end;
      end
      else
      if (Categ = 'PGLIBINDICE') then
      // Champ crit�re de maintien = Indice
      begin
{$IFNDEF EAGLCLIENT}
         ChampLib := THDBMultiValComboBox(GetControl('PCM_VALCATEGORIE')); // PT6
{$ELSE}
         ChampLib := THMultiValComboBox(GetControl('PCM_VALCATEGORIE')); // PT6
{$ENDIF}
         if (GetField('PCM_CONVENTION') <> '') and
            (Getfield('PCM_CONVENTION') <> '000') then
         // on limite la tablette aux coefficients de la convention collective choisie
         begin
              if ChampLib <> nil then
                 ChampLib.Plus := ' AND PMI_CONVENTION = "' +
                                    GetField('PCM_CONVENTION')+
                                    '"';
         end;
      end
      else
      if (Categ = 'PGLIBNIVEAU') then
      // Champ crit�re de maintien = Niveau
      begin
{$IFNDEF EAGLCLIENT}
         ChampLib := THDBMultiValComboBox(GetControl('PCM_VALCATEGORIE')); // PT6
{$ELSE}
         ChampLib := THMultiValComboBox(GetControl('PCM_VALCATEGORIE')); // PT6
{$ENDIF}
         if (GetField('PCM_CONVENTION') <> '') and
            (Getfield('PCM_CONVENTION') <> '000') then
         // on limite la tablette aux coefficients de la convention collective choisie
         begin
              if ChampLib <> nil then
                 ChampLib.Plus := ' AND PMI_CONVENTION = "' +
                                    GetField('PCM_CONVENTION')+
                                    '"';
         end;
      end;
// f PT5
// f PT4
    end
    else
    begin //PT1
      Categ := '';
      LibCateg := ''; //PT1
    end; //PT1
    Ferme(Q);
  end;

  if not VH_Paie.PGMaintien then
  // Le maintien n'est pas appliqu�.
  begin
    SetControlEnabled('PCM_MAINTIENNET',False);
    SetControlVisible('PCM_MAINTIENNET',False);

    SetControlEnabled('PCM_CUMULPAIE',False);
    SetControlVisible('PCM_CUMULPAIE',False);
    SetControlVisible('TPCM_CUMULPAIE',False);

    SetControlEnabled('PCM_RUBMAINTIEN',False);
    SetControlVisible('PCM_RUBMAINTIEN',False);
    SetControlVisible('TPCM_RUBMAINTIEN',False);
    SetControlVisible('LRUBMAINT',False);
  end;

  if (State <> 'ACTION=CREATION') then
  begin
    SetControlEnabled('PCM_CODEMAINT', False);
    SetControlEnabled('PCM_PREDEFINI', False);
    SetControlEnabled('PCM_CONVENTION', False);
    SetControlEnabled('PCM_BORNEFINANC', False);
  end
  else
  begin
    SetControlEnabled('PCM_CODEMAINT', True);
    SetControlEnabled('PCM_PREDEFINI', True);
    SetControlEnabled('PCM_CONVENTION', True);
    SetControlEnabled('PCM_BORNEFINANC', True);
  end;


end ;

{***********A.G.L.Priv�.*****************************************
Auteur  ...... : PAIE- MF
Cr�� le ...... : 27/07/2004
Modifi� le ... :   /  /    
Description .. : proc�dure OnChangeField
Suite ........ : Traitement cons�cutifs � la modification de certains champs
Mots clefs ... : PAIE; MAINTIEN
*****************************************************************}
procedure TOM_CRITMAINTIEN.OnChangeField ( F: TField ) ;
var
  Pred,CodeMaint                                 : string;
// d PT4
{$IFNDEF EAGLCLIENT}
  ChampLib                                      : THDBMultiValComboBox;
{$ELSE}
  ChampLib                                      : THMultiValComboBox;
{$ENDIF}
// f PT4
begin
  Inherited ;
  // Code Maintien : alphanum�rique sur 5 caract�res.
  // dans le cas d'une saisie num�rique "incompl�te" le champ est
  // format� (ajout de z�ros � gauche)
  if (F.FieldName = 'PCM_CODEMAINT')  and (DS.State = dsinsert) then
  begin
    if (GetField('PCM_CODEMAINT') <> '') then
    begin
      CodeMaint := GetField('PCM_CODEMAINT');
      if (IsNumeric(GetField('PCM_CODEMAINT')) and (length(CodeMaint) <> 5)) then
        SetField('PCM_CODEMAINT',ColleZeroDevant(GetField('PCM_CODEMAINT'),5))
      else
        if (length(CodeMaint) <> 5) then
        begin
          PGIBox('Saisir 5 Caract�res', 'Anomalie de saisie');
          SetFocusControl('PCM_CODEMAINT');
        end;
    end
    else
      if (State = 'ACTION=CREATION') then
        SetFocusControl('PCM_CODEMAINT');
  end;

  // Pr�d�fini
  if (F.FieldName = 'PCM_PREDEFINI') and (DS.State = dsinsert) then
  begin
    Pred := GetField('PCM_PREDEFINI');
    if Pred = '' then exit;
    if (Pred = 'CEG') and (CEG = FALSE) then
    begin
      PGIBox('Vous ne pouvez pas cr�er de crit�re pr�d�fini CEGID', 'Acc�s refus�');
      Pred := 'DOS';
      SetControlProperty('PCM_PREDEFINI', 'Value', Pred);
    end;
    if (Pred = 'STD') and (STD = FALSE) then
    begin
      PGIBox('Vous ne pouvez pas cr�er de crit�re pr�d�fini Standard', 'Acc�s refus�');
      Pred := 'DOS';
      SetControlProperty('PCM_PREDEFINI', 'Value', Pred);
    end;
    if Pred <> GetField('PCM_PREDEFINI') then
      SetField('PCM_PREDEFINI', pred);
    if (pred = 'DOS') then
      SetField('PCM_NODOSSIER',PgRendNoDossier)
    else
      SetField('PCM_NODOSSIER','000000');

  end;

  // d�but anciennet� - contr�le valeur
  if (F.FieldName = 'PCM_BORNEDEBANC') and (GetField('PCM_BORNEDEBANC') <> 0) then
    if (GetField('PCM_BORNEFINANC') <> 0) then
      if (GetField('PCM_BORNEDEBANC') > GetField('PCM_BORNEFINANC')) then
      begin
        PGIBox('La borne fin d''anciennet� doit �tre sup�rieure � la borne debut d''anciennet�', 'Anomalie de saisie');
        SetFocusControl('PCM_BORNEDEBANC');
      end;
  // fin anciennet� - contr�le valeur
  if (F.FieldName = 'PCM_BORNEFINANC') then
      if (GetField('PCM_BORNEDEBANC') > GetField('PCM_BORNEFINANC')) then
      begin
        PGIBox('La borne fin d''anciennet� doit �tre sup�rieure � la borne debut d''anciennet�', 'Anomalie de saisie');
        SetFocusControl('PCM_BORNEFINANC');
      end;

  // case � cocher "Maintien du net"
  if (F.FieldName = 'PCM_MAINTIENNET') and (DS.State = dsinsert) then
// d PT3
//    SetControlText('PCM_CUMULPAIE', 'NET');
     SetField('PCM_CUMULPAIE', 'NET');
// f PT3

// d PT4
  // convention collective
  if (F.FieldName = 'PCM_CONVENTION') then
  begin
      if (Categ = 'PGLIBCOEFFICIENT') then
      // Champ crit�re de maintien = Coefficient
      begin
{$IFNDEF EAGLCLIENT}
         ChampLib := THDBMultiValComboBox(GetControl('PCM_VALCATEGORIE')); // PT6
{$ELSE}
         ChampLib := THMultiValComboBox(GetControl('PCM_VALCATEGORIE')); // PT6
{$ENDIF}
         if (GetField('PCM_CONVENTION') <> '') and
            (Getfield('PCM_CONVENTION') <> '000') then
         // on limite la tablette aux coefficients de la convention collective choisie
         begin
              if ChampLib <> nil then
// d PT7
//               ChampLib.Plus := ' PMI_NATURE = "COE" AND '+
                 ChampLib.Plus := ' AND '+
                                  '(PMI_CONVENTION = "' +
                                    GetField('PCM_CONVENTION')+
                                    '")';
         end;
{
         else
         // tablette de tous les coefficients de toutes les conventions du dossier
         begin
             if ChampLib <> nil then
                 ChampLib.Plus := ' PMI_NATURE="COE" ';
         end ;}
// f PT7
      end
// d PT5
      else
      if (Categ = 'PGLIBQUALIFICATION') then
      // Champ crit�re de maintien = Qualification
      begin
{$IFNDEF EAGLCLIENT}
         ChampLib := THDBMultiValComboBox(GetControl('PCM_VALCATEGORIE'));   // PT6
{$ELSE}
         ChampLib := THMultiValComboBox(GetControl('PCM_VALCATEGORIE'));     // PT6
{$ENDIF}
         if (GetField('PCM_CONVENTION') <> '') and
            (Getfield('PCM_CONVENTION') <> '000') then
         // on limite la tablette aux coefficients de la convention collective choisie
         begin
              if ChampLib <> nil then
                 ChampLib.Plus := ' AND PMI_CONVENTION = "' +
                                    GetField('PCM_CONVENTION')+
                                    '"';
         end ;
      end
      else
      if (Categ = 'PGLIBINDICE') then
      // Champ crit�re de maintien = Indice
      begin
{$IFNDEF EAGLCLIENT}
         ChampLib := THDBMultiValComboBox(GetControl('PCM_VALCATEGORIE')); // PT6
{$ELSE}
         ChampLib := THMultiValComboBox(GetControl('PCM_VALCATEGORIE')); // PT6
{$ENDIF}
         if (GetField('PCM_CONVENTION') <> '') and
            (Getfield('PCM_CONVENTION') <> '000') then
         // on limite la tablette aux coefficients de la convention collective choisie
         begin
              if ChampLib <> nil then
                 ChampLib.Plus := ' AND PMI_CONVENTION = "' +
                                    GetField('PCM_CONVENTION')+
                                    '"';
         end;
      end
      else
      if (Categ = 'PGLIBNIVEAU') then
      // Champ crit�re de maintien = Niveau
      begin
{$IFNDEF EAGLCLIENT}
         ChampLib := THDBMultiValComboBox(GetControl('PCM_VALCATEGORIE')); // PT6
{$ELSE}
         ChampLib := THMultiValComboBox(GetControl('PCM_VALCATEGORIE')); // PT6
{$ENDIF}
         if (GetField('PCM_CONVENTION') <> '') and
            (Getfield('PCM_CONVENTION') <> '000') then
         // on limite la tablette aux coefficients de la convention collective choisie
         begin
              if ChampLib <> nil then
                 ChampLib.Plus := '  AND PMI_CONVENTION = "' +
                                    GetField('PCM_CONVENTION')+
                                    '"';
         end ;
      end ;
// f PT5
  end;
// f PT4

end ;

{***********A.G.L.Priv�.*****************************************
Auteur  ...... : PAIE- MF
Cr�� le ...... : 27/07/2004
Modifi� le ... : 27/07/2004
Description .. : proc�dure OnArgument
Suite ........ : Chargement de la fiche : param�trage des champs 
Suite ........ : d�pendant de param�tres soci�t� ou de l'acc�s pr�d�fini.
Suite ........ : param�trage de boutons
Mots clefs ... : PAIE; MAINTIEN
*****************************************************************}
procedure TOM_CRITMAINTIEN.OnArgument ( S: String ) ;
var
  BtnRegle,BtnDuplic                            : TToolBarButton97;
begin
  Inherited ;
  State :=(Trim(ReadTokenSt(S)));

  AccesPredefini('TOUS', CEG, STD, DOS);

  BtnRegle:= TToolBarButton97(GetControl('BGESTIONASS'));
  if BtnRegle <> nil then BtnRegle.onClick := BGESTIONASSClick;

  BtnDuplic := TToolBarButton97(GetControl('BDUPLIQUER'));
  if BtnDuplic <> nil then BtnDuplic.OnClick := DupliquerTableMaintien;

  // raz indicateurs de duplication et de modification
  Duplique := False;
  Modifie := False;
  RegleAssociee := False;

  AncValCod := '';
  AncConv := '';
  AncBorneFin := '';

end ;

{***********A.G.L.Priv�.*****************************************
Auteur  ...... : PAIE- MF
Cr�� le ...... : 27/07/2004
Modifi� le ... : 27/07/2004
Description .. : proc�dure OnClose
Suite ........ : A la fermeture de la fiche suppression des �l�ments 
Suite ........ : REGLESMAINTIEN cons�cutifs � une duplication  non 
Suite ........ : valid�e.
Mots clefs ... : PAIE; MAINTIEN
*****************************************************************}
procedure TOM_CRITMAINTIEN.OnClose ;
begin
  Inherited ;

  if (Duplique = true) and (Modifie = false) then
  // il y a eu duplication mais pas de validation, il faut supprimer
  // les REGLESMAINTIEN qui ont �t� cr��es par la duplication
  begin
    ExecuteSQL('DELETE FROM REGLESMAINTIEN WHERE '+
               'PAM_PREDEFINI ="'+
               GetField('PCM_PREDEFINI')+'"'+
               ' AND PAM_CODEMAINT="'+
               GetField('PCM_CODEMAINT')+'"'+
               ' AND PAM_NODOSSIER="'+
               GetField('PCM_NODOSSIER')+'"'+
               ' AND PAM_CONVENTION="'+
               GetField('PCM_CONVENTION')+'"'+
               ' AND PAM_BORNEFINANC='+ // PT2
               GetControlText('PCM_BORNEFINANC'));
  end;
end ;

procedure TOM_CRITMAINTIEN.OnCancelRecord ;
begin
  Inherited ;
end ;

{***********A.G.L.Priv�.*****************************************
Auteur  ...... : PAIE- MF
Cr�� le ...... : 27/07/2004
Modifi� le ... :   /  /    
Description .. : Proc�dure BGESTIONASSClick
Suite ........ : Lancement de la fiche REGLESMAINTIEN associ�e � la 
Suite ........ : table CRITMAINTIEN trait�e.
Suite ........ : La validation de la fiche CRITMAINTIEN est auparavant 
Suite ........ : forc�e
Mots clefs ... : PAIE; MAINTIEN
*****************************************************************}
procedure TOM_CRITMAINTIEN.BGESTIONASSClick (Sender: TObject);
// d PT1
var
  ValCateg              : string;
  i                     : integer;
// f PT1
begin
  // Validation de la fiche CRITMAINTIEN
  RegleAssociee := True;
  TFFiche(Ecran).BValiderClick(Sender);
// d PT1
  ValCateg := GetField('PCM_VALCATEGORIE'); // PT6
  for i := 1 to length(ValCateg) do
  begin
    if (ValCateg[i] = ';') then
      ValCateg[i] := ' ';
  end;
// f PT1
  // Lancement de la fiche REGLESMAINTIEN ( les r�gles a� aplliquer)
  AglLanceFiche('PAY','REGLESMAINTIEN','','',GetField('PCM_CODEMAINT')+';'+
                                             GetField('PCM_LIBELLE')+';'+
                                             GetField('PCM_CONVENTION')+';'+
                                             ValCateg+';'+
                                             IntToStr( GetField('PCM_BORNEFINANC'))+';'+
                                             GetField('PCM_PREDEFINI')+';'+
                                             GetField('PCM_NODOSSIER')+';'+
                                             LibCateg);
  RegleAssociee := False;
  if not (ds.state in [dsinsert, dsedit]) then ds.edit;
  TFFiche(Ecran).BValiderClick(Sender);

end;

{***********A.G.L.Priv�.*****************************************
Auteur  ...... : PAIE- MF
Cr�� le ...... : 27/07/2004
Modifi� le ... : 27/07/2004
Description .. : proc�dure DupliquerTableMaintien
Suite ........ : duplication de l'�l�ment CRITMAINTIEN et des �l�ments 
Suite ........ : REGLES MAINTIEN associ�s
Mots clefs ... : PAIE; MAINTIEN
*****************************************************************}
procedure TOM_CRITMAINTIEN.DupliquerTableMaintien(Sender: TObject);
var
  st,NoDossier          : string;
  ok                                                            : boolean;
  Q                                                             : TQuery;

begin

 AncValCod := GetField('PCM_CODEMAINT');
 AncConv := GetField('PCM_CONVENTION');
 AncBorneFin := IntToStr(GetField('PCM_BORNEFINANC'));

 // lancement de la fiche de duplication de code (nb: m�me tratitement que pour
 // la ducs--> cf 5�me param�tre)
 AglLanceFiche('PAY', 'CODE', '', '', 'DUC;' + AncValCod + '; ;5');

 if PGCodeDupliquer <> '' then
 begin
   // Alimention du n� de dossier en fct du pr�d�fini
   if PGCodePredefini = 'DOS' then
     NoDossier := PgRendNoDossier()
   else
     NoDossier := '000000';

   // formatage et contr�le du Code Maintien
   if (IsNumeric(PGCodeDupliquer) and (length(PGCodeDupliquer) <> 5)) then
     PGCodeDupliquer := ColleZeroDevant(StrToInt(PGCodeDupliquer),5)
   else
     if (length(PGCodeDupliquer) <> 5) then
     begin
       PGIBox('Saisir un code sur 5 Caract�res', 'Anomalie de saisie');
       exit;
     end;

   // Recherche si code inexistant
   ok := false;
   st := 'SELECT * FROM CRITMAINTIEN'+
         ' WHERE PCM_PREDEFINI="'+ PGCodePredefini +'" AND'+
         ' PCM_NODOSSIER="'+ NoDossier +'" AND'+
         ' PCM_CODEMAINT="'+ PGCodeDupliquer + '" AND '+
         ' PCM_BORNEFINANC="'+IntToStr(GetField('PCM_BORNEFINANC'))+'" AND'+
         ' PCM_CONVENTION="'+ +GetField('PCM_CONVENTION')+'" ';
   Q := OpenSql(st, TRUE);
   if not Q.eof then
     ok := True;
   ferme(Q);

   if Ok = False then //Test si code existe ou non
   begin
     // duplication de la fiche CRITMAINTIEN (affichage avec valeur
     // du nouvel �l�ment
     DupliquerPaie(TFFiche(Ecran).TableName, TFFiche(Ecran));

     SetField('PCM_CODEMAINT', PGCodeDupliquer);
     SetField('PCM_PREDEFINI', PGCodePredefini);

     SetField('PCM_BORNEFINANC', StrToInt(AncBorneFin));
     duplique := true;

   end
   else
      PGIBox('Ce code existe d�j�', 'Duplication impossible');
 end;
end;

Initialization
  registerclasses ( [ TOM_CRITMAINTIEN ] ) ;
end.
