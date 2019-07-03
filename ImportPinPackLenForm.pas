{..............................................................................}
{ Summary Pin Package Lengths Importer script.
{         The ImportPinPackLenForm is the main form.                           }
{         You need a Pin Package Length Data CSV file to import                }
{         onto a Component symbol                                              }
{                                                                              }
{ To use the script:                                                           }
{  1/ Select the component in schematic that is going to be updated            }
{  2/ Execute the ImportPins procedure and the Pins Importer dialog appears    }
{  3/ Click on browse button to load in the CSV file of schematic pins data.   }
{  4/ Click on the Update Mapping button to refresh the links between          }
{     text fields and pin properties, then click on Execute button to generate }
{     the pin length data for the selected component                           }
{                                                                              }
{..............................................................................}

{..............................................................................}
Interface
Type
  TImportPinsForm = class(TForm)
    ButtonBrowse        : TButton;
    ButtonUpdateMapping : TButton;
    ButtonImport        : TButton;
    ListView            : TListView;
    OpenDialog          : TOpenDialog;
    Edit                : TEdit;
    procedure ButtonBrowseClick(Sender: TObject);
    procedure ButtonUpdateMappingClick(Sender: TObject);
    procedure ButtonImportClick(Sender: TObject);
  End;

Var
    ImportPinsForm : TImportPinsForm;
    SchDoc         : ISch_Document;
{..............................................................................}

{..............................................................................}
Procedure TImportPinsForm.ButtonBrowseClick(Sender: TObject);
Begin
    If OpenDialog.Execute Then Edit.Text := OpenDialog.FileName;
End;
{..............................................................................}

{..............................................................................}
Procedure AddListViewItem(ItemIndex: Integer; ItemCaption: String);
Var
    i : Integer ;
Begin
    ListView.Items.Add;
    ListView.Items[ItemIndex].Caption := ItemCaption;
    For i := 0 To FormChangeMapping.ComboBox.Items.Count-1 Do
        If UpperCase(ItemCaption) = UpperCase(FormChangeMapping.ComboBox.Items[i]) Then
        Begin
            ListView.Items[ItemIndex].SubItems.Add(FormChangeMapping.ComboBox.Items[i]);
            ListView.Items[ItemIndex].Checked := True;
            Exit;
        End;
    ListView.Items[ItemIndex].SubItems.Add('');
End;
{..............................................................................}

{..............................................................................}
procedure TImportPinsForm.ButtonUpdateMappingClick(Sender: TObject);
Var
    StrList     : TStringList ;
    ValuesCount : Integer     ;
    i, j        : Integer     ;
Begin
    If Edit.Text = '' Then Exit;

    StrList := TStringList.Create;
    Try
        StrList.LoadFromFile(Edit.Text);
        ListView.Clear;

        ValuesCount := 1 ;
        j           := 1 ;
        For i := 1 To Length(StrList[0]) Do
            If (Copy(StrList[0], i, 1) = ',') Then
            Begin
                AddListViewItem(ValuesCount-1, Copy(StrList[0], j, i-j));
                j := i+1;
                Inc(ValuesCount);
            End;
        If ValuesCount > 1 Then
            AddListViewItem(ValuesCount-1, Copy(StrList[0], j, Length(StrList[0])+1-j));
    Finally
        StrList.Free;
    End;
End;
{..............................................................................}

{..............................................................................}
// Iterate through pins on the selected schematic symbol, check if they match
// the selected pin and if they do update the length
Function UpdatePinLength(CSVBall: TPCBString, CSVLenStr: String): Boolean;
Var
     CurrentSch       : ISch_Sheet             ;
     Iterator         : ISch_Iterator          ;
     PIterator        : ISch_Iterator          ;
     AComponent       : ISch_Component         ;
     Pin              : ISch_Pin               ;
     CompDes          : TPCBString             ;
     CompBall         : TPCBString             ;
     CSVLenCoord      : Integer                ;
Begin
     Result := False;

     // Check if schematic server exists or not.
     If SchServer = Nil Then Exit;

     // Obtain the current schematic document interface.
     CurrentSch := SchServer.GetCurrentSchDocument;
     If CurrentSch = Nil Then Exit;

     // Look for components only
     Iterator := CurrentSch.SchIterator_Create;
     Iterator.AddFilter_ObjectSet(MkSet(eSchComponent));

     Try
         AComponent := Iterator.FirstSchObject;
         While AComponent <> Nil Do
         Begin
             CompDes := AComponent.Designator.Text;
             If AComponent.Selection Then
                 Try
                     PIterator := AComponent.SchIterator_Create;
                     PIterator.AddFilter_ObjectSet(MkSet(ePin));

                     Pin := PIterator.FirstSchObject;
                     While Pin <> Nil Do
                     Begin
                         CompBall := Pin.Designator;

                         If CompBall = CSVBall Then
                            Begin
                                 StringToCoordUnit(CSVLenStr, CSVLenCoord, eImperial);

                                 pin.PinPackageLength := CSVLenCoord; // Set Pin Length
                                 Result := True;
                            End;

                         Pin := PIterator.NextSchObject;
                     End;
                 Finally
                     AComponent.SchIterator_Destroy(PIterator);
                 End;

             AComponent := Iterator.NextSchObject;
         End;
     Finally
         CurrentSch.SchIterator_Destroy(Iterator);
     End;
End;
{..............................................................................}

{..............................................................................}
Procedure TImportPinsForm.ButtonImportClick(Sender: TObject);
Var
    ValuesCount      : Integer       ;
    i, j, k, l       : Integer       ;
    TxtFieldValue    : String        ;
    PinProperty      : String        ;
    StrList          : TStringList   ;
    Location         : TLocation     ;
    PinLocX, PinLocY : Integer       ;
    PinLocMapped     : Boolean       ;
    CSVBall          : String        ;
    CSVLenStr        : String        ;
Begin
    // check if file exists or not
    If Not(FileExists(Edit.Text)) or (Edit.Text = '') Then
    Begin
        ShowWarning('The Pin Data CSV format file doesnt exist!');
        Exit;
    End;

    StrList := TStringList.Create;
    Try
        StrList.LoadFromFile(Edit.Text); // CSV with pin/package lengths

        // Iterate CSV Rows
        For j := 1 To StrList.Count-1 Do
        Begin

            For i := 0 To ListView.Items.Count-1 Do
            Begin
                If ListView.Items[i].Checked Then
                Begin
                    TxtFieldValue := '';
                    ValuesCount   := 1 ;
                    k             := 1 ;
                    For l := 1 To Length(StrList[j]) Do
                        If (Copy(StrList[j], l, 1) = ',') Then
                        Begin
                            If ValuesCount = i+1 Then
                            Begin
                                TxtFieldValue := Copy(StrList[j], k, l-k);
                                k := l+1;
                                Inc(ValuesCount);
                                Break;
                            End;
                            k := l+1;
                            Inc(ValuesCount);
                        End;
                    If ValuesCount = i+1 Then TxtFieldValue := Copy(StrList[j], k, Length(StrList[j])+1-k);

                    PinProperty := UpperCase(ListView.Items[i].SubItems.Strings[0]);

                    If PinProperty = 'DESIGNATOR' Then
                        Begin
                            CSVBall := TxtFieldValue;
                        End
                    Else If PinProperty = 'LENGTH' Then
                        Begin
                            CSVLenStr := TxtFieldValue;
                        End
                End;
            End;
            // Check csv against component pin length
            UpdatePinLength(CSVBall, CSVLenStr);
        End;
    Finally
        StrList.Free;
    End;

    SchDoc.GraphicallyInvalidate;

    ResetParameters;
    AddStringParameter('Action', 'All');
    RunProcess('Sch:Zoom');

    Close;
End;
{..............................................................................}

{..............................................................................}
Procedure RunImportPins;
Begin
    If SchServer = Nil Then Exit;
    SchDoc := SchServer.GetCurrentSchDocument;
    If SchDoc = Nil Then Exit;

    // check if it is a schematic library document
    If Not SchDoc.IsLibrary Then Exit;

    ImportPinsForm.ShowModal;
End;
{..............................................................................}

{..............................................................................}
