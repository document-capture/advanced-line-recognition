codeunit 61003 "ALR CDC Capture Engine"
{
    // Original Object ID : 6085575


    trigger OnRun()
    begin
    end;

    var
        GlobalWords: Record "CDC Document Word" temporary;
        CaptureMgt: Codeunit "CDC Capture Management";
        ContiniaLicenseMgt: Codeunit "CDC Continia License Mgt.";
        Window: Dialog;
        BuffWordDocNo: Code[20];
        BuffWordPageNo: Integer;
        Text001: Label 'Processing Document\#1######################';
        Text002: Label 'Performing Identfication';
        Text003: Label 'Processing Header';
        Text004: Label 'Processing Lines';
        HideWindow: Boolean;
        IdentificationFieldsTxt: Label 'Identification Fields: %1';
        XmlDoc: Codeunit "CDC Continia XML Document";
        ObjType: Option TableData,"Table",Form,"Report",Dataport,"Codeunit","XMLport",MenuSuite,"Page",System,FieldNumber;
        ErrorNoXMLModule: Label 'You do not have access to Document Capture XML Import module. ';
        "<ALR Var>": Integer;
        LineRegionFromPage: Integer;
        LineRegionFromPos: Integer;
        LineRegionToPage: Integer;
        LineRegionToPos: Integer;
        "</ALR Var>": Integer;

    procedure CaptureDocument(var Document: Record "CDC Document")
    var
        Template: Record "CDC Template";
        "Field": Record "CDC Template Field";
        Value: Record "CDC Document Value";
        TemplateGroup: Record "CDC Document Category";
        Comment: Record "CDC Document Comment";
        CDCModuleLicense: Codeunit "CDC Module License";
        DocumentComment: Record "CDC Document Comment";
    begin
        Document.TESTFIELD(Status, Document.Status::Open);

        IF GUIALLOWED AND (NOT HideWindow) THEN BEGIN
            Window.OPEN(Text001);
            Window.UPDATE(1, Text002);
        END;

        IF (Document."File Type" = Document."File Type"::XML) AND NOT ContiniaLicenseMgt.HasLicenseAccessToDCXml THEN BEGIN
            Document.DeleteComments(DocumentComment.Area::Capture);
            DocumentComment.Add(Document, Field, 0, DocumentComment.Area::Capture, DocumentComment."Comment Type"::Error,
              ErrorNoXMLModule);
        END;

        IF (Document."Source Record ID Tree ID" = 0) OR (Document."Template No." = '') THEN BEGIN
            FindDocumentSource(Document);

            IF Document."Template No." = '' THEN BEGIN
                IF Document."Source Record ID Tree ID" <> 0 THEN
                    Document.ValidateDocument;

                IF GUIALLOWED AND (NOT HideWindow) THEN
                    Window.CLOSE;

                EXIT;
            END;
        END;
        Template.GET(Document."Template No.");

        Value.SETRANGE("Document No.", Document."No.");
        Value.SETRANGE("Is Value", TRUE);
        Value.DELETEALL(TRUE);

        IF GUIALLOWED AND (NOT HideWindow) THEN
            Window.UPDATE(1, Text003);

        Document."Match Status" := Document."Match Status"::Unmatched;
        Document.MODIFY;
        Document.DeleteComments(Comment.Area::Match);

        Field.SETCURRENTKEY("Template No.", Type, "Sort Order");
        Field.SETRANGE("Template No.", Document."Template No.");
        Field.SETRANGE(Type, Field.Type::Header);
        IF Field.FINDSET(FALSE, FALSE) THEN
            REPEAT
                IF (NOT UseFixedValue(Document, Field, 0)) THEN
                    IF Field."Search for Value" THEN
                        IF CaptureField(Document, 0, Field, TRUE) = '' THEN
                            CaptureMgt.UpdateFieldValue(Document."No.", 0, 0, Field, '', TRUE, FALSE);
            UNTIL Field.NEXT = 0;

        IF CDCModuleLicense.IsAdvCaptureActivated(FALSE) THEN
            IF (Template."Recognize Lines" = Template."Recognize Lines"::Yes) AND (Template."Codeunit ID: Line Capture" <> 0) THEN BEGIN
                IF GUIALLOWED AND (NOT HideWindow) THEN
                    Window.UPDATE(1, Text004);

                IF ContiniaLicenseMgt.HasExecutePermission(ObjType::Codeunit, Template."Codeunit ID: Line Capture") THEN
                    CODEUNIT.RUN(Template."Codeunit ID: Line Capture", Document);
            END;

        Document.AfterCapture;
        Document.ValidateDocument;

        IF GUIALLOWED AND (NOT HideWindow) THEN
            Window.CLOSE;
    end;

    procedure CaptureField(var Document: Record "CDC Document"; PageNo: Integer; var "Field": Record "CDC Template Field"; UpdateFieldCaption: Boolean) Word: Text[1024]
    var
        DummyFieldCaption: Record "CDC Template Field Caption";
    begin
        EXIT(CaptureField2(Document, PageNo, Field, UpdateFieldCaption, DummyFieldCaption));
    end;

    procedure CaptureField2(var Document: Record "CDC Document"; PageNo: Integer; var "Field": Record "CDC Template Field"; UpdateFieldCaption: Boolean; var FieldCaption: Record "CDC Template Field Caption") Word: Text[1024]
    var
        "Page": Record "CDC Document Page";
        Value: Record "CDC Document Value";
        PrevPage: Record "CDC Document Page";
        PrevValue: Record "CDC Document Value";
        Top: Integer;
        Left: Integer;
        Bottom: Integer;
        Right: Integer;
    begin
        IF Document."File Type" = Document."File Type"::XML THEN BEGIN
            Word := CaptureMgt.CaptureFromXML(Document, Field, 0, TRUE, Value, XmlDoc);
            EXIT(Word);
        END;

        FieldCaption.SETCURRENTKEY("Template No.", Type, Code, "Caption Length");
        FieldCaption.SETRANGE("Template No.", Field."Template No.");
        FieldCaption.SETRANGE(Type, Field.Type);
        FieldCaption.SETRANGE(Code, Field.Code);
        FieldCaption.SETFILTER(Caption, '<>%1', '');
        FieldCaption.ASCENDING(FALSE);

        // *********************************************************************************************************************************
        // FIND THE VALUE BY OFFSETTING CAPTION
        // *********************************************************************************************************************************
        IF (Field."Caption Offset X" <> 0) OR (Field."Caption Offset Y" <> 0) OR (Field."Caption Is Part Of Value") THEN BEGIN
            IF FieldCaption.FIND('-') THEN
                REPEAT
                    Word := FindWordFromCaption(Document."No.", PageNo, Field, FieldCaption, FALSE);
                    IF Word <> '' THEN BEGIN
                        IF UpdateFieldCaption THEN
                            CaptureMgt.UpdateFieldCaption(Field, FieldCaption."Page No.", FieldCaption.Top, FieldCaption.Left, FieldCaption.DPI,
                              FieldCaption.Caption);
                        EXIT(Word);
                    END;
                UNTIL FieldCaption.NEXT = 0;
        END;

        // *********************************************************************************************************************************
        // FIND THE VALUE BY SEARCHING FROM THE CAPTION LIST
        // *********************************************************************************************************************************
        IF (Field."Caption Offset X" = 0) OR (Field."Caption Offset Y" = 0) THEN BEGIN
            IF FieldCaption.FIND('-') THEN
                REPEAT
                    Word := FindWordFromCaption(Document."No.", PageNo, Field, FieldCaption, TRUE);
                    IF Word <> '' THEN BEGIN
                        IF UpdateFieldCaption THEN
                            CaptureMgt.UpdateFieldCaption(Field, FieldCaption."Page No.", FieldCaption.Top, FieldCaption.Left, FieldCaption.DPI,
                              FieldCaption.Caption);
                        EXIT(Word);
                    END;
                UNTIL FieldCaption.NEXT = 0;
        END;

        // *********************************************************************************************************************************
        // FIND THE VALUE FROM THE REGION ALONE
        // *********************************************************************************************************************************
        IF NOT Field."Caption Mandatory" THEN BEGIN
            PrevValue.SETCURRENTKEY("Template No.", "Is Value", Type, Code);
            PrevValue.SETRANGE("Template No.", Field."Template No.");
            PrevValue.SETRANGE("Is Value", TRUE);
            PrevValue.SETRANGE(Type, Field.Type);
            PrevValue.SETRANGE(Code, Field.Code);
            PrevValue.SETFILTER("Document No.", '<>%1', Document."No.");
            PrevValue.SETFILTER(Top, '>%1', 0);
            PrevValue.SETFILTER(Left, '>%1', 0);
            IF PrevValue.FINDLAST THEN BEGIN
                Page.SETRANGE("Document No.", Document."No.");
                IF PageNo > 0 THEN
                    Page.SETRANGE("Page No.", PageNo);
                IF Field."Default Page Source" = Field."Default Page Source"::"First Page" THEN
                    Page.FINDFIRST
                ELSE
                    Page.FINDLAST;

                PrevPage.GET(PrevValue."Document No.", PrevValue."Page No.");

                Top := ROUND(PrevValue.Top * GetDPIFactor(PrevPage."TIFF Image Resolution", Page."TIFF Image Resolution"), 1);
                Left := ROUND(PrevValue.Left * GetDPIFactor(PrevPage."TIFF Image Resolution", Page."TIFF Image Resolution"), 1);
                Bottom := ROUND(PrevValue.Bottom * GetDPIFactor(PrevPage."TIFF Image Resolution", Page."TIFF Image Resolution"), 1);

                IF Field."Typical Field Width" <> 0 THEN
                    Right := Left + ROUND(Field."Typical Field Width" * GetDPIFactor(150, Page."TIFF Image Resolution"), 1)
                ELSE
                    Right := ROUND(PrevValue.Right * GetDPIFactor(PrevPage."TIFF Image Resolution", Page."TIFF Image Resolution"), 1);

                Word := CaptureMgt.CaptureFromPos(Page, Field, 0, TRUE, Top, Left, Bottom, Right, Value);

                IF CaptureMgt.ParseField(Field, Word, TRUE, Document."No.") THEN
                    EXIT(Word);
            END;
        END;
    end;

    procedure FindDocumentSource(var Document: Record "CDC Document")
    begin
        // *********************************************************************************************************************************
        // FIND THE SOURCE ID OF A DOCUMENT
        // *********************************************************************************************************************************

        // STEP 1: FIND SOURCE WITH SEARCH TEXTS
        IF FindSourceWithSearchTexts(Document) THEN
            EXIT;

        // STEP 2: FIND SOURCE WITH IDENTIFICATION TEMPLATE
        IF FindSourceWithIdentTemplate(Document) THEN
            EXIT;

        // STEP 3: FIND SOURCE WITH IDENTIFICATION FIELDS
        FindSourceWithIdentFields(Document);
    end;

    procedure FindSourceWithSearchTexts(var Document: Record "CDC Document"): Boolean
    begin
        CODEUNIT.RUN(CODEUNIT::"CDC Doc. - Search Word Ident.", Document);
        IF Document."Template No." <> '' THEN
            EXIT(TRUE);
    end;

    procedure FindSourceWithIdentTemplate(var Document: Record "CDC Document"): Boolean
    var
        DocCat: Record "CDC Document Category";
        Template: Record "CDC Template";
        IdentTemplate: Record "CDC Template";
        BestMatchPoints: Integer;
        BestSourceRecTreeID: Integer;
        BestIdentifiedBy: Text[1024];
        CurrXmlMasterTemplate: Code[20];
        CurrSourceRecTreeID: Integer;
        Template2: Record "CDC Template";
    begin
        Template.SETCURRENTKEY("Category Code", Type);
        Template.SETRANGE("Category Code", Document."Document Category Code");
        Template.SETRANGE(Type, Template.Type::Identification);

        IF Document."File Type" = Document."File Type"::XML THEN BEGIN
            IF NOT ContiniaLicenseMgt.HasLicenseAccessToDCXml THEN
                EXIT(FALSE);

            Template.SETRANGE("Data Type", Template."Data Type"::XML);
            Template.SETRANGE(Type, Template.Type::Master);

            CurrXmlMasterTemplate := Document."XML Master Template No.";
            CurrSourceRecTreeID := Document."Source Record ID Tree ID";

            IF Template.FINDSET(FALSE, FALSE) THEN
                REPEAT
                    IdentTemplate.GET(Template."XML Ident. Template No.");
                    IF IdentTemplate."Codeunit ID: After Capture" > 0 THEN BEGIN
                        Document."Temp Ident. Template No." := IdentTemplate."No.";
                        Document."Temp Master Template No." := Template."No.";
                        IF CurrSourceRecTreeID = 0 THEN
                            Document."Source Record ID Tree ID" := 0;

                        CODEUNIT.RUN(IdentTemplate."Codeunit ID: After Capture", Document);
                        IF Document."XML Identification Points" > BestMatchPoints THEN BEGIN
                            BestMatchPoints := Document."XML Identification Points";
                            Document."XML Master Template No." := Template."No.";
                            Document."XML Ident. Template No." := Document."Temp Ident. Template No.";
                            BestSourceRecTreeID := Document."Source Record ID Tree ID";
                            BestIdentifiedBy := Document."Identified by";
                        END;
                    END;
                UNTIL (Template.NEXT = 0);

            IF (BestMatchPoints > 0) AND (CurrXmlMasterTemplate <> Document."XML Master Template No.") THEN BEGIN
                Document.VALIDATE("XML Master Template No.");
                Document."Temp Ident. Template No." := '';
                Document."Temp Master Template No." := '';
                Document."XML Identification Points" := 0;
                Document.MODIFY(TRUE);
            END;

            IF BestSourceRecTreeID <> 0 THEN BEGIN
                Document.VALIDATE("Identified by", BestIdentifiedBy);
                Document.VALIDATE("Source Record ID Tree ID", BestSourceRecTreeID);
                Document.MODIFY(TRUE);
            END;

        END ELSE BEGIN
            Template.SETRANGE("Data Type", Template."Data Type"::PDF);
            IF Template.FINDSET(FALSE, FALSE) THEN
                REPEAT
                    IF Template."Codeunit ID: After Capture" > 0 THEN
                        CODEUNIT.RUN(Template."Codeunit ID: After Capture", Document);
                UNTIL (Document."Source Record ID Tree ID" <> 0) OR (Template.NEXT = 0);
        END;

        EXIT(Document."Source Record ID Tree ID" <> 0);
    end;

    procedure FindSourceWithIdentFields(var Document: Record "CDC Document"): Boolean
    var
        DocCat: Record "CDC Document Category";
        RecIDMgt: Codeunit "CDC Record ID Mgt.";
        RecRef: RecordRef;
        RecID: RecordID;
        MatchPoints: Integer;
        SourceID: Integer;
        IdentFieldNameValue: Text[1024];
    begin
        GetRecFromIdentField(Document, 1, RecID, MatchPoints, IdentFieldNameValue);
        IF MatchPoints >= 15 THEN BEGIN
            DocCat.GET(Document."Document Category Code");
            IF DocCat."Source Table No." <> 0 THEN BEGIN
                RecRef.GET(RecID);
                SourceID := RecIDMgt.GetRecIDTreeID(RecRef, TRUE);
                COMMIT;

                Document.VALIDATE("Source Record ID Tree ID", SourceID);
                Document."Identified by" := COPYSTR(STRSUBSTNO(IdentificationFieldsTxt, IdentFieldNameValue), 1,
                  MAXSTRLEN(Document."Identified by"));
                Document.MODIFY(TRUE);
                EXIT(TRUE);
            END;
        END ELSE
            Document."Identified by" := '';
    end;

    procedure FindWordFromCaption(DocumentNo: Code[20]; PageNo: Integer; var "Field": Record "CDC Template Field"; var FieldCaption: Record "CDC Template Field Caption"; DynamicsSearch: Boolean) Word: Text[1024]
    var
        CaptionStartWord: array[100] of Record "CDC Document Word";
        CaptionEndWord: array[100] of Record "CDC Document Word";
        "Page": Record "CDC Document Page";
        LeftWord: Record "CDC Document Word" temporary;
        TopWord: Record "CDC Document Word" temporary;
        Value: Record "CDC Document Value";
        WordFunc: Codeunit "CDC Word Functions";
        Length: Integer;
        Height: Integer;
        OffsetX: Integer;
        OffsetY: Integer;
        Top: Integer;
        Left: Integer;
        Bottom: Integer;
        Right: Integer;
        i: Integer;
        Stop: Boolean;
    begin
        IF NOT FindCaption(DocumentNo, PageNo, Field, FieldCaption, CaptionStartWord, CaptionEndWord) THEN
            EXIT;

        i := 1;
        REPEAT
            Page.GET(DocumentNo, CaptionStartWord[i]."Page No.");

            Length := ROUND(IIFInt(Field."Typical Field Width" <> 0, Field."Typical Field Width", 40) *
              GetDPIFactor(150, Page."TIFF Image Resolution"), 1);
            Height := ROUND(IIFInt(Field."Typical Field Height" <> 0, Field."Typical Field Height", 20) *
              GetDPIFactor(150, Page."TIFF Image Resolution"), 1);

            // STORE THE CAPTION
            CaptureMgt.CaptureFromPos(Page, Field, 0, FALSE,
              CaptionStartWord[i].Top, CaptionStartWord[i].Left, CaptionEndWord[i].Bottom, CaptionEndWord[i].Right, Value);

            IF NOT DynamicsSearch THEN BEGIN
                Top := IIFInt(Field."Caption Is Part Of Value", CaptionStartWord[i].Top, CaptionStartWord[i].Top +
                  ROUND(Field."Caption Offset Y" * GetDPIFactor(Field."Offset DPI", Page."TIFF Image Resolution"), 1));
                Left := IIFInt(Field."Caption Is Part Of Value", CaptionStartWord[i].Left, CaptionStartWord[i].Left +
                  ROUND(Field."Caption Offset X" * GetDPIFactor(Field."Offset DPI", Page."TIFF Image Resolution"), 1));
                Bottom := Top + Height;
                Right := Left + Length;

                Word := CaptureMgt.CaptureFromPos(Page, Field, 0, TRUE, Top, Left, Bottom, Right, Value);
                CaptureMgt.ParseField(Field, Word, TRUE, DocumentNo);
                EXIT(Word);
            END;

            // *******************************************************************************************************************************
            // IF DATATYPE IS NUMBER THEN TRY TO FIND THE VALUE BELOW CAPTION
            // *******************************************************************************************************************************
            IF Field."Data Type" = Field."Data Type"::Number THEN BEGIN
                Top := CaptionStartWord[i].Bottom + ROUND(((CaptionStartWord[i].Bottom - CaptionStartWord[i].Top) / 2), 1);
                Left := CaptionStartWord[i].Left;
                Bottom := Top + ((CaptionStartWord[i].Bottom - CaptionStartWord[i].Top));
                Right := CaptionEndWord[i].Right;

                Word := CaptureMgt.CaptureFromPos(Page, Field, 0, TRUE, Top, Left, Bottom, Right, Value);

                IF CaptureMgt.ParseField(Field, Word, TRUE, DocumentNo) THEN
                    EXIT(Word);
            END;

            // *******************************************************************************************************************************
            // SEARCH TO THE RIGHT OF CAPTION
            // *******************************************************************************************************************************
            Top := CaptionStartWord[i].Top + ROUND(((CaptionStartWord[i].Bottom - CaptionStartWord[i].Top) / 2), 1);

            Bottom := Top + 1;
            Left := IIFInt(Field."Caption Is Part Of Value", CaptionStartWord[i].Left,
              CaptionEndWord[i].Right + ROUND(10 * GetDPIFactor(0, Page."TIFF Image Resolution"), 1));
            Right := Left + ROUND(4000 * GetDPIFactor(0, Page."TIFF Image Resolution"), 1);

            IF WordFunc.GetFirstWordFromLeft(Page, Top, Left, Bottom, Right, LeftWord) THEN BEGIN
                Left := LeftWord.Left;
                Right := Left + Length;

                Word := CaptureMgt.CaptureFromPos(Page, Field, 0, TRUE, Top, Left, Bottom, Right, Value);
                IF CaptureMgt.ParseField(Field, Word, TRUE, DocumentNo) THEN
                    EXIT(Word);
            END;

            // *******************************************************************************************************************************
            // SEARCH BELOW CAPTION
            // *******************************************************************************************************************************
            Top := IIFInt(Field."Caption Is Part Of Value", CaptionStartWord[i].Top +
              ROUND(((CaptionStartWord[i].Bottom - CaptionStartWord[i].Top) / 2), 1),
              ROUND(CaptionStartWord[i].Bottom + ((CaptionStartWord[i].Bottom - CaptionStartWord[i].Top) / 2), 1));
            Left := CaptionStartWord[i].Left;
            Bottom := Top + ROUND(80 * GetDPIFactor(0, Page."TIFF Image Resolution"), 1);
            Right := CaptionEndWord[i].Right;

            IF WordFunc.GetFirstWordFromTop(Page, Top, Left, Bottom, Right, TopWord) THEN BEGIN
                Top := TopWord.Top;
                Bottom := TopWord.Bottom;

                Word := CaptureMgt.CaptureFromPos(Page, Field, 0, TRUE, Top, Left, Bottom, Right, Value);

                IF CaptureMgt.ParseField(Field, Word, TRUE, DocumentNo) THEN
                    EXIT(Word);
            END;

            IF i = 10 THEN
                Stop := TRUE
            ELSE BEGIN
                i := i + 1;
                Stop := CaptionStartWord[i].Word = '';
            END;
        UNTIL Stop;

        Word := '';
    end;

    procedure FindCaption(DocumentNo: Code[20]; PageNo: Integer; var "Field": Record "CDC Template Field"; FieldCaption: Record "CDC Template Field Caption"; var CaptionStartWord: array[100] of Record "CDC Document Word"; var CaptionEndWord: array[100] of Record "CDC Document Word"): Boolean
    var
        Doc: Record "CDC Document";
        "Page": Record "CDC Document Page";
        PrevPage: Record "CDC Document Page";
        PrevCaption: Record "CDC Document Value";
        StartWord: Record "CDC Document Word";
        EndWord: Record "CDC Document Word";
        TempResultWord: array[100, 2] of Record "CDC Document Word";
        Sorter: Record "Line Number Buffer" temporary;
        WordFunc: Codeunit "CDC Word Functions";
        CurrWord: Text[1024];
        WordFound: Text[1024];
        TempStr: Text[1024];
        I: Integer;
        NoOfCaptions: Integer;
        Found: Boolean;
        Stop: Boolean;
        PriorityTop: Integer;
        PriorityLeft: Integer;
        PagePriorityTop: Integer;
        PagePriorityLeft: Integer;
        PriorityPageNo: Integer;
        PrevDPIFactor: Integer;
        DPIFactor: Decimal;
    begin
        BufferWords(DocumentNo, PageNo);
        CLEAR(CaptionStartWord);
        CLEAR(CaptionEndWord);

        FieldCaption.Caption := UPPERCASE(DELCHR(FieldCaption.Caption, '=', ' '));
        GlobalWords.RESET;
        IF PageNo <> 0 THEN
            GlobalWords.SETRANGE("Page No.", PageNo);
        IF GlobalWords.FINDSET(FALSE, FALSE) THEN
            REPEAT
                CurrWord := UPPERCASE(DELCHR(GlobalWords.Word, '=', ' '));

                IF (StartWord.Word <> '') THEN BEGIN
                    IF NOT WordFunc.IsWordsOnSameLine(GlobalWords, StartWord) THEN BEGIN
                        CLEAR(StartWord);
                        WordFound := '';
                    END;
                END;

                IF STRPOS(CurrWord, FieldCaption.Caption) > 0 THEN BEGIN
                    StartWord := GlobalWords;
                    EndWord := GlobalWords;
                    WordFound := FieldCaption.Caption;
                END ELSE
                    IF ((StartWord.Word <> '') AND (EndWord.Word = '')) THEN BEGIN
                        IF (STRLEN(WordFound) + STRLEN(CurrWord) < STRLEN(FieldCaption.Caption)) THEN BEGIN
                            IF (CurrWord = COPYSTR(FieldCaption.Caption, STRLEN(WordFound) + 1, STRLEN(CurrWord))) THEN
                                WordFound := WordFound + CurrWord
                            ELSE BEGIN
                                CLEAR(StartWord);
                                WordFound := '';
                            END;
                        END ELSE
                            IF (COPYSTR(CurrWord, 1, STRLEN(FieldCaption.Caption) - STRLEN(WordFound)) =
                              COPYSTR(FieldCaption.Caption, STRLEN(WordFound) + 1))
                            THEN BEGIN
                                EndWord := GlobalWords;
                                WordFound := FieldCaption.Caption;
                            END ELSE BEGIN
                                CLEAR(StartWord);
                                WordFound := '';
                            END;
                    END ELSE BEGIN
                        CLEAR(StartWord);
                        WordFound := '';
                    END;

                // This will search the current word, and see if it ends with part of the string to search for
                IF WordFound = '' THEN BEGIN
                    TempStr := FieldCaption.Caption;
                    I := 0;
                    Stop := FALSE;
                    WHILE (I < STRLEN(FieldCaption.Caption)) AND NOT Stop DO BEGIN
                        I := I + 1;
                        TempStr := COPYSTR(FieldCaption.Caption, I, 1);
                        IF (STRPOS(CurrWord, WordFound + TempStr) > 0) THEN BEGIN
                            WordFound := WordFound + TempStr;
                            StartWord := GlobalWords;
                        END ELSE BEGIN
                            IF STRLEN(CurrWord) > I THEN BEGIN
                                WordFound := '';
                                CLEAR(StartWord);
                            END;
                            Stop := TRUE;
                        END;
                    END;
                END;

                IF (StartWord.Word <> '') AND (EndWord.Word <> '') THEN BEGIN
                    // Save the result for later comparision to other potential hits.
                    NoOfCaptions := NoOfCaptions + 1;
                    TempResultWord[NoOfCaptions, 1] := StartWord;
                    TempResultWord[NoOfCaptions, 2] := EndWord;

                    CLEAR(StartWord);
                    CLEAR(EndWord);
                    WordFound := '';
                END;
            UNTIL (GlobalWords.NEXT = 0) OR (NoOfCaptions = 100);

        // *******************************************************************************************************************
        // SELECT THE CAPTION THAT IS CLOSEST TO THE CAPTION THAT WAS ORIGINALLY SELECTED BY THE USER MANUALLY.
        // IF THE USER NEVER SELECTED THE CAPTION MANUALLY, THEN FIND THE LAST CAPTION AND PRIORITISE THE POSITION OF THAT.
        // *******************************************************************************************************************
        IF (FieldCaption.Top <> 0) OR (FieldCaption.Left <> 0) THEN BEGIN
            PrevDPIFactor := Field."Offset DPI";

            PriorityTop := FieldCaption.Top;
            PriorityLeft := FieldCaption.Left;
            PriorityPageNo := FieldCaption."Page No.";
        END ELSE BEGIN
            PrevCaption.SETCURRENTKEY("Template No.", "Is Value", Type, Code);
            PrevCaption.SETRANGE("Template No.", Field."Template No.");
            PrevCaption.SETRANGE("Is Value", FALSE);
            PrevCaption.SETRANGE(Type, Field.Type);
            PrevCaption.SETRANGE(Code, Field.Code);
            PrevCaption.SETFILTER(Top, '>%1', 0);
            PrevCaption.SETFILTER(Left, '>%1', 0);
            IF NOT PrevCaption.FINDLAST THEN
                CLEAR(PrevCaption);

            IF PrevPage.GET(PrevCaption."Document No.", PrevCaption."Page No.") THEN
                PrevDPIFactor := PrevPage."TIFF Image Resolution"
            ELSE
                PrevDPIFactor := 0;

            PriorityTop := PrevCaption.Top;
            PriorityLeft := PrevCaption.Left;
            PriorityPageNo := PrevCaption."Page No.";
        END;

        FOR I := 1 TO NoOfCaptions DO BEGIN
            Doc.GET(DocumentNo);
            Doc.CALCFIELDS("No. of Pages");

            Page.GET(DocumentNo, TempResultWord[I, 1]."Page No.");
            IF PrevDPIFactor <> 0 THEN
                DPIFactor := GetDPIFactor(PrevDPIFactor, Page."TIFF Image Resolution")
            ELSE
                DPIFactor := 1;
            PagePriorityTop := ROUND(PriorityTop * DPIFactor, 1);
            PagePriorityLeft := ROUND(PriorityLeft * DPIFactor, 1);

            Sorter."New Line Number" := I;
            Sorter."Old Line Number" := ABS((TempResultWord[I, 1].Top - PagePriorityTop) + (TempResultWord[I, 1].Left - PagePriorityLeft));
            IF (TempResultWord[I, 1]."Page No." = Doc."No. of Pages") AND
              (Field."Default Page Source" = Field."Default Page Source"::"Last Page")
            THEN
                Sorter."Old Line Number" := Sorter."Old Line Number" - 15000
            ELSE
                IF TempResultWord[I, 1]."Page No." = PriorityPageNo THEN
                    Sorter."Old Line Number" := Sorter."Old Line Number" - 10000 // Give words on same page as previous the higher priority
                ELSE
                    IF (TempResultWord[I, 1]."Page No." = 1) AND (Field."Default Page Source" = Field."Default Page Source"::"First Page") THEN
                        Sorter."Old Line Number" := Sorter."Old Line Number" - 5000;
            IF Sorter.INSERT THEN;
        END;

        I := 0;
        IF Sorter.FINDSET(FALSE, FALSE) THEN
            REPEAT
                I := I + 1;
                CaptionStartWord[I] := TempResultWord[Sorter."New Line Number", 1];
                CaptionEndWord[I] := TempResultWord[Sorter."New Line Number", 2];
            UNTIL (Sorter.NEXT = 0) OR (I = 10);

        EXIT(CaptionStartWord[1].Word <> '');
    end;

    procedure UseFixedValue(var Document: Record "CDC Document"; var "Field": Record "CDC Template Field"; LineNo: Integer): Boolean
    var
        RecIDMgt: Codeunit "CDC Record ID Mgt.";
    begin
        CASE Field."Data Type" OF
            Field."Data Type"::Text:
                BEGIN
                    IF Field."Fixed Value (Text)" <> '' THEN BEGIN
                        CaptureMgt.UpdateFieldValue(Document."No.", 0, LineNo, Field, Field."Fixed Value (Text)", TRUE, FALSE);
                        EXIT(TRUE);
                    END
                END;

            Field."Data Type"::Number:
                BEGIN
                    IF Field."Fixed Value (Decimal)" <> 0 THEN BEGIN
                        IF Field."Decimal Places" = '' THEN
                            CaptureMgt.UpdateFieldValue(Document."No.", 0, LineNo, Field, FORMAT(Field."Fixed Value (Decimal)"), TRUE, FALSE)
                        ELSE
                            CaptureMgt.UpdateFieldValue(Document."No.", 0, LineNo, Field,
                              FORMAT(Field."Fixed Value (Decimal)", 0, STRSUBSTNO('<Precision,%1><Standard Format,0>', Field."Decimal Places")), TRUE,
                                FALSE);

                        EXIT(TRUE);
                    END;
                END;

            Field."Data Type"::Date:
                BEGIN
                    IF Field."Fixed Value (Date)" <> 0D THEN BEGIN
                        CaptureMgt.UpdateFieldValue(Document."No.", 0, LineNo, Field, FORMAT(Field."Fixed Value (Date)"), TRUE, FALSE);
                        EXIT(TRUE);
                    END ELSE
                        IF Field."Fixed Value (Text)" = 'TODAY' THEN BEGIN
                            CaptureMgt.UpdateFieldValue(Document."No.", 0, LineNo, Field, FORMAT(TODAY), TRUE, FALSE);
                            EXIT(TRUE);
                        END;
                END;

            Field."Data Type"::Lookup:
                BEGIN
                    IF Field."Fixed Value (Rec. ID Tree ID)" <> 0 THEN BEGIN
                        CaptureMgt.UpdateFieldValue(Document."No.", 0, LineNo, Field,
                          RecIDMgt.GetKeyValue(Field."Fixed Value (Rec. ID Tree ID)", Field."Source Field No."), TRUE, FALSE);
                        EXIT(TRUE);
                    END;
                END;

            Field."Data Type"::Boolean:
                BEGIN
                    IF Field."Fixed Value (Boolean)" THEN BEGIN
                        CaptureMgt.UpdateFieldValue(Document."No.", 0, LineNo, Field, FORMAT(Field."Fixed Value (Boolean)"), TRUE, FALSE);
                        EXIT(TRUE);
                    END;
                END;
        END;
    end;

    procedure IIFInt(TestValue: Boolean; ValueIfTrue: Integer; ValueIfFalse: Integer): Decimal
    begin
        IF TestValue THEN
            EXIT(ValueIfTrue)
        ELSE
            EXIT(ValueIfFalse);
    end;

    procedure IntersectsWith(var Value: Record "CDC Document Value"; var Value2: Record "CDC Document Value"): Boolean
    begin
        IF (Value.Left = Value2.Left) AND (Value.Right = Value2.Right) AND
          (Value.Top = Value2.Top) AND (Value.Bottom = Value2.Bottom)
        THEN
            EXIT(TRUE);

        EXIT(
          (Value.Left <= Value2.Right) AND (Value2.Left <= Value.Right) AND
          (Value.Top <= Value2.Bottom) AND (Value2.Top <= Value.Bottom));
    end;

    procedure BufferWords(DocumentNo: Code[20]; PageNo: Integer)
    var
        Words: Record "CDC Document Word";
        ALRDocumentPage: Record "CDC Document Page";
    begin
        IF (BuffWordDocNo = DocumentNo) AND ((BuffWordPageNo = PageNo) OR (BuffWordPageNo = 0)) THEN
            EXIT;

        GlobalWords.RESET;
        GlobalWords.DELETEALL;

        Words.SETRANGE("Document No.", DocumentNo);
        //<ALR>
        if (LineRegionFromPage > 0) or (LineRegionToPage > 0) then begin
            ALRDocumentPage.SetRange("Document No.", DocumentNo);
            ALRDocumentPage.SetRange("Page No.", LineRegionFromPage, LineRegionToPage);
            if ALRDocumentPage.FindSet then
                repeat
                    if LineRegionToPos = 0 then
                        Words.SetFilter(Top, StrSubstNo('%1..%2', LineRegionFromPos, ALRDocumentPage."Bottom Word Pos."))
                    else
                        Words.SetFilter(Top, DelChr(StrSubstNo('%1..%2', LineRegionFromPos, LineRegionToPos), '=', ' '));

                    if Words.FindSet(false, false) then
                        repeat
                            GlobalWords := Words;
                            GlobalWords.Insert;
                        until Words.Next = 0;
                until ALRDocumentPage.Next = 0;
        end else begin
            //</ALR>
            IF PageNo <> 0 THEN
                Words.SETRANGE("Page No.", PageNo);
            IF Words.FINDSET(FALSE, FALSE) THEN
                REPEAT
                    GlobalWords := Words;
                    GlobalWords.INSERT;
                UNTIL Words.NEXT = 0;
            //<ALR>
        end;
        //</ALR>
        BuffWordDocNo := DocumentNo;
        BuffWordPageNo := PageNo;
    end;

    procedure GetNextBottom(var "Page": Record "CDC Document Page"; var Bottom: Integer; var Height: Integer; var MinLeft: Integer; var MaxRight: Integer): Boolean
    begin
        GlobalWords.SETCURRENTKEY("Document No.", "Page No.", Bottom);
        GlobalWords.SETRANGE("Document No.", Page."Document No.");
        GlobalWords.SETRANGE("Page No.", Page."Page No.");
        GlobalWords.SETFILTER(Bottom, '>%1', Bottom);
        GlobalWords.SETFILTER(Left, '>=%1', MinLeft);
        GlobalWords.SETFILTER(Right, '<=%1', MaxRight);
        IF GlobalWords.FINDSET(FALSE, FALSE) THEN BEGIN
            Bottom := GlobalWords.Bottom;
            Height := ROUND(GlobalWords.Bottom - GlobalWords.Top, 1);
            EXIT(TRUE);
        END ELSE BEGIN
            Bottom := 99999;
            EXIT(FALSE);
        END;
    end;

    procedure SetHideWindow(NewHideWindow: Boolean)
    begin
        HideWindow := NewHideWindow
    end;

    procedure GetRecFromIdentField(var Document: Record "CDC Document"; PageNo: Integer; var RecID: RecordID; var Points: Integer; var IdentFields: Text[1024])
    var
        DocCat: Record "CDC Document Category";
        IdentifierField: Record "CDC Doc. Category Ident. Field";
        DocWord: Record "CDC Document Word";
        SourceExcl: Record "CDC Document Cat. Source Excl.";
        TempLookupRecID: Record "CDC Temp. Lookup Record ID";
        BigString: Codeunit "CDC BigString Management";
        RecIDMgt: Codeunit "CDC Record ID Mgt.";
        RecRef: RecordRef;
        BestRecRef: RecordRef;
        BestIdentificationFields: Text[1024];
        FieldRef: FieldRef;
        IdentificationFields: Text[1024];
        IdentFieldNameAndValue: Text[1024];
        BestRecMatchPoint: Integer;
        RecMatchPoint: Integer;
        RecIDTreeID: Integer;
        RecPoints: Integer;
        XMLBuffer: Record "CDC XML Buffer";
    begin
        IdentifierField.SETRANGE("Document Category Code", Document."Document Category Code");
        IF NOT IdentifierField.FINDFIRST THEN
            EXIT;

        DocCat.GET(Document."Document Category Code");
        TempLookupRecID."Table No." := IdentifierField."Table No.";
        TempLookupRecID."Table Filter GUID" := DocCat."Document Category GUID";
        RecRef.OPEN(IdentifierField."Table No.");
        RecIDMgt.GetView(RecRef, TempLookupRecID);

        IF Document."File Type" = Document."File Type"::XML THEN BEGIN
            Document.BuildXmlBuffer(XMLBuffer);
            XMLBuffer.SETFILTER(Type, '%1|%2', XMLBuffer.Type::Element, XMLBuffer.Type::Attribute);
            IF NOT XMLBuffer.FINDSET(FALSE, FALSE) THEN
                EXIT;

            REPEAT
                BigString.Append(UPPERCASE(DELCHR(XMLBuffer.Value, '=', ' ,.-;:/\*+')));
            UNTIL XMLBuffer.NEXT = 0;
        END ELSE BEGIN
            DocWord.SETRANGE("Document No.", Document."No.");
            DocWord.SETRANGE("Page No.", PageNo);
            IF NOT DocWord.FINDSET(FALSE, FALSE) THEN
                EXIT;

            REPEAT
                BigString.Append(UPPERCASE(DELCHR(DocWord.Word, '=', ' ,.-;:/\*+-')));
            UNTIL DocWord.NEXT = 0;
        END;

        REPEAT
            RecIDTreeID := RecIDMgt.GetRecIDTreeID(RecRef, FALSE);
            IF NOT SourceExcl.GET(Document."Document Category Code", RecIDTreeID) THEN BEGIN
                RecMatchPoint := 0;
                IdentificationFields := '';
                IF IdentifierField.FINDSET THEN
                    REPEAT
                        FieldRef := RecRef.FIELD(IdentifierField."Field No.");
                        RecPoints := GetPoints(FORMAT(FieldRef.VALUE), BigString, STRLEN(FORMAT(FieldRef.VALUE))) * IdentifierField.Rating;
                        IF RecPoints > 0 THEN BEGIN
                            RecMatchPoint += RecPoints;
                            IdentifierField.CALCFIELDS("Field Caption");
                            IdentFieldNameAndValue := IdentifierField."Field Caption" + ': ' + FORMAT(FieldRef.VALUE);

                            IF IdentificationFields <> '' THEN
                                IdentificationFields := IdentificationFields + ', ';

                            IF STRLEN(IdentificationFields + IdentFieldNameAndValue) <= 1024 THEN
                                IdentificationFields := IdentificationFields + IdentFieldNameAndValue;
                        END;
                    UNTIL IdentifierField.NEXT = 0;

                IF BestRecMatchPoint < RecMatchPoint THEN BEGIN
                    BestRecMatchPoint := RecMatchPoint;
                    BestRecRef := RecRef.DUPLICATE;
                    BestIdentificationFields := IdentificationFields;
                END;
            END;
        UNTIL RecRef.NEXT = 0;

        CLEAR(RecRef);

        IF FORMAT(BestRecRef) = '' THEN
            EXIT;

        RecID := BestRecRef.RECORDID;
        Points := BestRecMatchPoint;
        IdentFields := BestIdentificationFields;
        CLEAR(BestRecRef);
    end;

    procedure GetPoints(Text: Text[250]; var BigString: Codeunit "CDC BigString Management"; Points: Integer): Integer
    begin
        Text := UPPERCASE(DELCHR(Text, '=', ' ,.-;:/\*+-'));
        IF (Text <> '') AND (BigString.IndexOf(Text) <> -1) THEN
            EXIT(Points);
    end;

    procedure GetDPIFactor(OldDPI: Integer; NewDPI: Integer): Decimal
    begin
        IF OldDPI = NewDPI THEN
            EXIT(1);

        IF OldDPI = 0 THEN
            OldDPI := 150;

        IF NewDPI = 0 THEN
            NewDPI := 150;

        EXIT(NewDPI / OldDPI);
    end;

    procedure SetLineRegion(FromPage: Integer; FromPos: Integer; ToPage: Integer; ToPos: Integer)
    begin
        LineRegionFromPage := FromPage;
        LineRegionFromPos := FromPos;
        LineRegionToPage := ToPage;
        LineRegionToPos := ToPos;
        Clear(BuffWordDocNo);
        Clear(BuffWordPageNo);
    end;
}
