{***********UNITE*************************************************
Auteur  ...... : MBO
Cr�� le ...... : 20/04/2006
Modifi� le ... :   /  /
Description .. : Source TOF de la FICHE : AMMODIFSERVICE ()
Mots clefs ... : TOF;AMMODIFSERVICE
Suite..........: // Particularit�s en Mise � jour de IMMOLOG
Suite..........: // ATTENTION : l'ancienne date deb eco est stock�e dans il_codemutation
Suite..........: //             l'ancienne date deb fis est stock�e dans il_codeeclat
Suite..........: FQ 18119 05/06 BTY Positionner les indicateurs de modif de compta dans PARAMSOC
Suite......... : FQ 17923 - mbo - 22.06.2006 - la date deb amort doit �tre sup�rieure ou �gale � la
                            + petite des dates entre date d'achat et date de mise en service
                 FQ 19090 - MVG 09/11/2006           
*****************************************************************}
Unit AMMODIFSERVICE_TOF ;

Interface

Uses StdCtrls,
     Controls,
     Classes,
     Forms,
     Windows,
     Menus,
     Graphics,
{$IFNDEF EAGLCLIENT}
     db,
     {$IFNDEF DBXPRESS} dbtables, {$ELSE} uDbxDataSet, {$ENDIF}
     mul,
     fe_main,
{$else}
     eMul,
     MaineAGL,
{$ENDIF}
     ImEnt,
     ImPlan,
     ImOuPlan,
     Chanplan,
     Outils,
     sysutils,
     ComCtrls,
     HCtrls,
     HEnt1,
     HMsgBox,
     UTOM,
     uTOB,
     ParamSoc,
     HRichOle,
     LookUp,
     HTB97,
     AGLInit,
     UTOF,
     Vierge;

Type
  TOF_AMMODIFSERVICE = Class (TOF)

    procedure OnUpdate                 ; override ;
    procedure OnArgument (S : String ) ; override ;
    procedure OnAfterFormShowEcran     ;

  private
    { Variables }
    fCode_immo : String;
    fPlan:TPlanAmort;
    fdatetest: string;
    fDateAchat: string;  // fq 17923
    fOldMs: string;
    fOldEco: string;
    fOldFis: string;
    fdatevide:string;
    fPlanActifAv: integer;
    fPlanActifAp: integer;
    fDP_BLOCNOTE: THRichEditOLE;

    procedure OnbFermeClick(Sender: TObject);
    procedure OnExitDateMS(Sender:TObject);
    Function  ControleDateOpe  :Boolean;
    Function  ControleNewDate  :Boolean;
    // fq 17923 : ajout du param�tre date_mini  ds les 2 f� de controle
    Function  COntroleDateEco(DateDeb:string ; date_mini:string) : boolean;
    Function  ControleDateFis(DateDebEco:string; DateDebFis:string ; date_mini:string) :Boolean;
  end ;

Function AMLanceFiche_AMMODIFSERVICE(stCode: string):Integer;

Implementation
const
  // fq 17923 : ajout du message 13
  HM: array[0..13] of string =
  ('Il n''est pas possible de pratiquer plusieurs modifications des dates de d�but d''amortissement dans l''exercice.',
    'La saisie de la date est obligatoire.',
    'La date de mise en service doit �tre sup�rieure � la date de d�but de l''exercice en cours.',
    'La date de l''op�ration doit �tre sup�rieure ou �gale � la plus haute date d''op�ration d�j� enregistr�e.',
    'Voulez-vous enregistrer cette op�ration ?',
    'L''immobilisation ne doit pas avoir �t� amortie sur un exercice pr�c�dent.',
    'La nouvelle date de mise en service doit �tre diff�rente de la date de mise en service d�j� saisie.',
    'Vous devez modifier une date pour pouvoir enregistrer l''op�ration.',
    'La date de l''op�ration doit appartenir � l''exercice en cours.',
    'L''enregistrement de la d�pr�ciation � �chou�.',
    'La date de d�but d''amortissement doit �tre sup�rieure ou �gale � la date de d�but de l''exercice en cours.',
    'La date de d�but d''amortissement fiscal doit �tre ant�rieure ou �gale � la date de d�but d''amortissement �conomique.',
    'Op�ration non disponible sur une immobilisation avec plan d''amortissement variable.' +
    'Veuillez supprimer et recr�er l''immobilisation.',
    'La date de d�but d''amortissement ne peut �tre ant�rieure � la plus petite des dates entre ' +
      'la date d''achat et la date de mise en service.');

 {***********A.G.L.***********************************************
Auteur  ...... : MBO
Cr�� le ...... : 20/04/2006
Modifi� le ... :   /  /
Description .. :  Activation de la fen�tre Modification date mise en service
Mots clefs ... :
*****************************************************************}
Function AMLanceFiche_AMMODIFSERVICE(Stcode: string):Integer;
var
   Qplan:tQuery;
   fPlan:TplanAmort;
   fCumulEco:double;
   fCumulFisc:double;
   fMethodeEco:string;
begin
   result := 0;

   // Ctl pr�sence immo avec op�ration d�pr�ciation
   if ExisteSQL ('SELECT IL_IMMO FROM IMMOLOG WHERE IL_IMMO="'+
    Stcode+'" AND IL_TYPEOP="MMS" AND IL_DATEOP >="'+
    USDATETIME(VHImmo^.EnCours.Deb)+'" AND IL_DATEOP <="'+
    USDATETIME(VHImmo^.EnCours.Fin)+'" ') then
      PGIBox(HM[0])
   else
   begin

       fPlan:=TPlanAmort.Create(true) ;
       QPlan:=OpenSQL('SELECT * FROM IMMO WHERE I_IMMO="'+Stcode+'"', FALSE) ;
       fPlan.Charge(QPlan);
       fPlan.Recupere(stCode,QPlan.FindField('I_PLANACTIF').AsString);
       fMethodeEco := fPlan.Amorteco.methode;
       // Calcul des anterieurs
       fPlan.GetCumulsDotExercice(VHImmo^.Encours.Deb,fCumulEco,fCumulFisc,false,true,false);

       fPlan.Free ; Ferme(QPlan);

       if fmethodeEco = 'VAR' then
          PGIBox(HM[12])
       else
       begin
          if (fCumulEco <> 0) or (fCumulFisc <> 0) then
          begin
              PGIBox(HM[5]);
          end else
              result:=StrToInt(AGLLanceFiche('AM', 'AMMODIFSERVICE','' , '', Stcode));
       end;
   end;
end;


procedure TOF_AMMODIFSERVICE.OnArgument (S : String ) ;
var QPlan : TQuery;
 begin
  Inherited ;

    // Initialisation
    TToolbarButton97(GetControl('BFerme')).Onclick := OnbFermeClick;
    TFVIERGE(ECRAN).retour := IntToStr(MrNo);
    TFVIERGE(ECRAN).OnAfterFormShow := OnAfterFormShowEcran;

    // Assignation du bloc note
    fDP_BLOCNOTE := THRichEditOLE(GetControl('MS_BLOCNOTE'));

    // Lecture de l'immo en cours
    fPlan:=TPlanAmort.Create(true) ;
    fCode_immo := S;
    QPlan:=OpenSQL('SELECT * FROM IMMO WHERE I_IMMO="'+fCode_immo+'"', FALSE) ;
    fPlan.Charge(QPlan);
    fPlan.Recupere(fCode_immo,QPlan.FindField('I_PLANACTIF').AsString);

    SetControlCaption('MS_CODE',fCode_immo);
    SetControlCaption('MS_COMPTE',fPlan.CompteImmo);
    SetControlCaption('MS_DESI',fPlan.libelleImmo);
    SetControlCaption('MS_ACHAT', DateToStr(fPlan.dateachat));
    SetControlCaption('MS_BECO',StrFMontant(fPlan.AmortEco.Base,15,V_PGI.OkDecV,'',True));
    SetControlCaption('MS_SERVICE', DateToStr(fPlan.DateMiseEnService));
    fOldEco  := DateToStr(fPlan.DateDebEco);
    fOldFis  := DateToStr(fPlan.DateDebFis);
    fOldMS   := DateToStr(fPlan.DateMiseEnService);
    fDateAchat := DateToStr(fPlan.DateAchat);  // ajout fq 17923
    SetControlCaption('MS_QUANTITE',IntToStr(Qplan.FindField('I_QUANTITE').AsInteger));

    SetControlText('MS_NEWDAT', DateToStr(fPlan.DateMiseEnService));
    SetControlText('MS_NEWECO', fOldEco);
    SetControlText('MS_NEWFIS', fOldFis);

    ThEdit(GetControl ('MS_NEWDAT')).OnExit := OnExitDateMS;

    if fplan.fiscal = true then
    begin
       SetControlCaption('MS_BFISC',StrFMontant(fPlan.AmortFisc.Base,15,V_PGI.OkDecV,'',True));
       if (fPlan.Amortfisc.methode = 'DEG') or (fPlan.amortfisc.methode = 'VAR') then
           SetControlEnabled(('MS_NEWFIS'), false);
    end
    else
    begin
       SetControlVisible('MS_BFISC', false);
       SetControlVisible('MS_LIBFISC', false);
       SetControlVisible('MS_LINEWFIS', false);
       SetControlVisible('MS_NEWFIS', false);
    end;

end ;


procedure TOF_AMMODIFSERVICE.OnAfterFormShowEcran;
begin
  Inherited ;

  // sauvegarde de la date initiale
  fdatetest := GetControlText('MS_DATOP');
  fdatevide := fdatetest;

  {$IFDEF SERIE1}
  SetControlText('MS_DATOP',DateToStr(V_PGI.DateEntree)); //YCP 25/06/2006
  {$ELSE}
  {$ENDIF}
  

end;

{***********A.G.L.***********************************************
Auteur  ...... : mbo
Cr�� le ...... : 15/05/2006
Modifi� le ... :   /  /    
Description .. : On repositionne les dates d�but d'amortissement 
Suite ........ : en fonction de la date de mise en service 
Mots clefs ... : 
*****************************************************************}
procedure TOF_AMMODIFSERVICE.OnExitDateMS(Sender:TObject);

begin
   if (fOldeco = fOldMS) then
      SetControlText('MS_NEWECO', GetControlText('MS_NEWDAT'));

   if (fPlan.fiscal = true) and (fOldFis = fOldMS) and (fPlan.AmortFisc.Methode <> 'DEG') then
      SetControlText('MS_NEWFIS', GetControlText('MS_NEWDAT'));
end;


{***********A.G.L.***********************************************
Auteur  ...... : Maryse BOUDIN
Cr�� le ...... : 21/04/2006
Modifi� le ... :   /  /
Description .. : controle de la date d'op�ration
Mots clefs ... :
*****************************************************************}
Function TOF_AMMODIFSERVICE.ControleDateOpe:Boolean;
var date_saisie: TdateTime;
    dd :string;
begin

  result := False;

  dd:= GetControlText('MS_DATOP');
  if dd = fdatetest then
    Begin
      result := True;
      PGIBox(HM[1]);
      SetFocusControl('MS_DATOP');
    End
  Else
    Begin
      date_saisie := StrToDate(GetControlText('MS_DATOP'));
      // la date doit appartenir � l'exercice en cours
      if (date_saisie >  VHImmo^.Encours.Fin) OR ( date_saisie < VHImmo^.Encours.Deb) then
        begin
          PGIBox(HM[8]);
          result := True;
          SetFocusControl('MS_DATOP');
        end
        // date de l'op�ration doit �tre > date derni�re op�ration
      else if ExisteSQL('SELECT IL_DATEOP FROM IMMOLOG WHERE IL_IMMO="'+fCode_immo+'" AND IL_DATEOP>"'+USDATETIME(date_saisie)+'"') then
        begin
          PGIBox(HM[3]);
          result := True;
          SetFocusControl('MS_DATOP');
        end;
     end;
end;


{***********A.G.L.***********************************************
Auteur  ...... : Maryse BOUDIN
Cr�� le ...... : 21/04/2006
Modifi� le ... :   /  /
Description .. : Contr�le de la date de mise en service
Mots clefs ... :
*****************************************************************}
Function TOF_AMMODIFSERVICE.ControleNewDate:Boolean;

begin

  result := False;

  if GetControlText('MS_NEWDAT') = fdatevide then
  begin
     result := True;
     PGIBox(HM[1]);
     //SetFocusControl('MS_NEWDAT');
  end;

  {Else
  Begin
      date_saisie := StrToDate(GetControlText('MS_NEWDAT'));
      // la date doit �tre sup�rieure � la date de d�but de l'exercice en cours
      if (date_saisie < VHImmo^.Encours.Deb) then
      begin
         PGIBox(HM[2]);
         result := True;
         //SetFocusControl('MS_NEWDAT');
      end;
   end; }
end;

{***********A.G.L.***********************************************
Auteur  ...... : mbo
Cr�� le ...... : 10/05/2006
Modifi� le ... :   /  /
Description .. : Controle de la date de d�but d'amortissement �co
Suite ........ : fq 17923  elle doit �tre > la + petite entre date d'achat et date mms
Mots clefs ... :
*****************************************************************}
Function TOF_AMMODIFSERVICE.ControleDateEco(DateDeb:string; date_mini:string) :Boolean;
var date_saisie: TdateTime;

begin
  result := False;

  if datedeb = fdatevide then
    begin
     result := True;
     PGIBox(HM[1]);
   end
  Else
  Begin
      date_saisie := StrToDate(DateDeb);
      // la date doit �tre sup�rieure � la date de d�but de l'exercice en cours
      if (date_saisie < VHImmo^.Encours.Deb) then
      begin
         PGIBox(HM[10]);
         result := True;
      end else            // ajout le 22.06.06 - fq 17923
      begin
         if date_saisie < StrToDate(date_mini) then
         begin
            PGIBox(HM[13]);
            result := True;
         end;
      end;
   end;
end;

{***********A.G.L.***********************************************
Auteur  ...... : mbo
Cr�� le ...... : 10/05/2006
Modifi� le ... :   /  /
Description .. : la date debut d'amort fiscal doit �tre inf�rieure ou
Suite ........ : �gale � la date de d�but d'amort eco
Suite......... : fq 17923 : et >= la plus petite entre date achat et date mms
Mots clefs ... :
*****************************************************************}
Function TOF_AMMODIFSERVICE.ControleDateFis(DateDebEco:string; DateDebFis:string; date_mini:string) :Boolean;
var date_saisie: TdateTime;

begin
  result := False;

  if datedebFis = fdatevide then
  begin
     result := True;
     PGIBox(HM[1]);
  end
  Else
  Begin
      date_saisie := StrToDate(DateDebFis);
      // la date doit �tre sup�rieure � la date de d�but de l'exercice en cours
      if (date_saisie < VHImmo^.Encours.Deb) then
      begin
         PGIBox(HM[10]);
         result := True;
      end
      else
      begin
         if (StrToDate(DatedebFis) > StrToDate(DateDebEco)) then
         begin
             PGIBox(HM[11]);
             result := True;
         end else
         begin  // ajout fq 17923
            if date_saisie < StrToDate(date_mini) then
            begin
              PGIBox(HM[13]);
              result := True;
            end;
         end;
      end;
  end;
end;

 {***********A.G.L.***********************************************
Auteur  ...... : mbo
Cr�� le ...... : 21/04/2006
Modifi� le ... :   /  /
Description .. : controle et validation de l'op�ration
Mots clefs ... :
*****************************************************************}
procedure TOF_AMMODIFSERVICE.OnUpdate ;
var Ordre : integer;
    TLog : TOB;
    lib :String;
    erreur : Boolean;
    QPlan : TQuery;
    PlanNew : TPlanAmort;
    Date_Mini : string;

begin
  Inherited ;
  ecran.ModalResult := mrYes;

   // Controle de la date de l'op�ration
   erreur := ControleDateOpe;
   IF erreur=True then
   Begin
       ecran.ModalResult :=mrNone;
       SetFocusControl('MS_DATOP');
       exit;
   end;

   // controle de la date de mise en service
   erreur := ControleNewDate;
   IF erreur=True then
   Begin
       ecran.ModalResult :=mrNone;
       SetFocusControl('MS_NEWDAT');
       exit;
   end;

   date_mini := GetControlText('MS_NEWDAT');
   if StrToDate(fDateAchat) < StrToDate(date_mini) then
      date_mini := fDateAchat;

   // contr�le de la date de d�but d'amort �co
   erreur := ControleDateEco(GetControlText('MS_NEWECO'), Date_mini);
   if erreur = true then
   begin
       ecran.ModalResult :=mrNone;
       SetFocusControl('MS_NEWECO');
       exit;
   end;

   // contr�le de la date de d�but d'amort �co
   if (fPlan.fiscal = true) then
   begin
      erreur := ControleDateFis(GetControlText('MS_NEWECO'), GetControlText('MS_NEWFIS'), date_mini);
      if erreur = true then
      begin
          ecran.ModalResult :=mrNone;
          SetFocusControl('MS_NEWFIS');
          exit;
      end;
   end;
   IF (GetControlText('MS_NEWDAT') = fOldMS) and
      (GetControlText('MS_NEWECO') = fOldEco) and
      (GetControlText('MS_NEWFIS') = fOldFis) then
   begin
       PGIBox(HM[7]);
       ecran.ModalResult :=mrNone;
       exit;
   end;

   // Mise � jour des dates les tables IMMO,IMMOAMOR et IMMOLOG
   BEGINTRANS ;
   try

      // Mise � jour de IMMO
      QPlan:=OpenSQL('SELECT * FROM IMMO WHERE I_IMMO="'+fCode_immo+'"', FALSE) ;

      // Maj de la fiche immo
      QPlan.Edit;
      QPlan.FindField('I_OPERATION').AsString:= 'X' ;
      QPlan.FindField('I_OPECHANGEPLAN').AsString:= 'X' ;
      QPlan.FindField('I_DATEAMORT').AsDateTime:= StrToDate(GetControlText('MS_NEWDAT'));
      QPlan.FIndField('I_DATEDEBECO').AsDateTime:= StrToDate(GetControlText('MS_NEWECO'));
      QPlan.FIndField('I_DATEDEBFIS').AsDateTime:= StrToDate(GetControlText('MS_NEWFIS'));
      QPlan.Post;

      // Maj du plan d'amortissement IMMOAMOR
      QPlan.Edit;
      PlanNew:=TPlanAmort.Create(true) ;
      try
         PlanNew.Charge(QPlan);
         PlanNew.Recupere(fCode_immo,QPlan.FindField('I_PLANACTIF').AsString);
         fPlanActifAv := PlanNew.NumSeq;
         PlanNew.SetTypeOpe('MMS');
         PlanNew.Calcul(Qplan, idate1900);
         PlanNew.Sauve;

         // Attribuer � l'immo le n� du nouveau plan d'amortissement
         Qplan.FindField('I_PLANACTIF').AsInteger := PlanNew.NumSeq;
         QPlan.FindField('I_DATEDERMVTECO').AsDateTime := PlanNew.GetDateFinAmortEx(PlanNew.AmortEco);
         QPlan.FindField('I_DATEDERNMVTFISC').AsDateTime := PlanNew.GetDateFinAmortEx(PlanNew.AmortFisc);

         Qplan.Post;
         fPlanActifAp := PlanNew.NumSeq;

      finally
         PlanNew.Free;
         Ferme(Qplan);
      end;


      // Mise � jour de IMMOLOG
      // ATTENTION : l'ancienne date deb eco est stock�e dans il_codemutation
      //             l'ancienne date deb fis est stock�e dans il_codeeclat

      lib:= 'Modification date d�but d''amortissement';
      Ordre := TrouveNumeroOrdreLogSuivant(fPlan.CodeImmo);

      TLog := TOB.Create ('IMMOLOG',nil,-1);
      try
         TLog.PutValue('IL_IMMO',fCode_immo);
         TLog.PutValue('IL_LIBELLE',lib);
         TLog.PutValue('IL_TYPEMODIF',AffecteCommentaireOperation('MMS'));

         TLog.PutValue('IL_DATEOP', StrToDate(GetControlText('MS_DATOP')));
         TLog.PutValue('IL_DATEOPREELLE', StrToDate(GetControlText('MS_SERVICE')));

         TLog.PutValue('IL_CODEMUTATION', fOldEco);
         TLog.PutValue('IL_CODEECLAT', fOldFis);

         TLog.PutValue('IL_TYPEOP', 'MMS');
         TLog.PutValue('IL_ORDRE', Ordre);
         TLog.PutValue('IL_OrdreSerie', -1);
         TLog.PutValue('IL_PLANACTIFAV', fPlanActifAv);
         TLog.PutValue('IL_PLANACTIFAP', fPlanActifAp);
         TLog.PutValue('IL_BLOCNOTE', RichToString (fDP_Blocnote));
         TLog.InsertDB(nil);
      finally
         TLog.Free;
      end;

      COMMITTRANS ;

      // 05/06 FQ 18119 Positionner les indicateurs de modif
      VHImmo^.ChargeOBImmo := True;
      ImMarquerPublifi (True);

   except
      PGIBox(HM[9]);
      ROLLBACK ;
   end ;

   TFVIERGE(ECRAN).retour := IntToStr(MrYes);
end ;



{***********A.G.L.***********************************************
Auteur  ...... : mbo
Cr�� le ...... : 21/04/2006
Modifi� le ... :   /  /
Description .. : sortie par x ou par esc : test si modif
Suite ........ : et question voulez-vous mettre � jour ?
Mots clefs ... :
*****************************************************************}
procedure TOF_AMMODIFSERVICE.OnbFermeCLick(Sender: TObject);
Var
    question : TmodalResult;
begin
  Inherited ;

  IF (GetControlText('MS_NEWDAT')=foldMS) and (GetControlText('MS_NEWECO')= fOldEco) and
     (GetControlText('MS_NEWFIS')= fOldFis) THEN
    Begin
      // Pas de saisie on sort
      Ecran.ModalResult := mrNo;
    end
  Else
    Begin
     // Action Echap ou Fermer par la croix
     Question := PGIAskCancel(HM[4],Ecran.Caption);
     If Question = mrYes then
        // contr�le validation
        OnUpdate
     else If Question = mrNo then
        // Sortir
        Ecran.ModalResult := mrNo
     else
        // Cancel
        Ecran.ModalResult := mrNone;
    end

end ;


Initialization
  registerclasses ( [ TOF_AMMODIFSERVICE ] ) ;
end.



