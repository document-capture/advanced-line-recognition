page 61000 "ALR Field rule examples"
{
    ApplicationArea = All;
    Caption = 'Field rule examples';
    PageType = List;
    SourceTable = Item;
    SourceTableTemporary = true;
    UsageCategory = Lists;
    InsertAllowed = false;
    ModifyAllowed = false;
    DeleteAllowed = false;

    layout
    {
        area(content)
        {
            repeater(General)
            {
                ShowAsTree = true;
                TreeInitialState = ExpandAll;
                IndentationColumn = Rec."Statistics Group";
                field("Rule"; Rec."Description 2")
                {
                    Caption = 'Rule';
                    ToolTip = 'Specifies the rule';
                    ApplicationArea = All;
                    Style = Strong;
                    StyleExpr = (Rec."Statistics Group" = 0);
                }
                field("Description"; Rec."Description")
                {
                    Caption = 'Rule description';
                    ToolTip = 'Describes the rule';
                    ApplicationArea = All;
                }

            }
        }
    }

    trigger OnOpenPage()
    var
        i: Integer;
    begin
        InsertRuleExamples();
    end;

    procedure InsertRuleExamples()
    var
        RuleNo: Integer;
    begin
        InsertRuleExample(RuleNo, 'Header rules', 'Typical rules for header fields', 0);
        InsertRuleExample(RuleNo, Rule1, RuleDescription1, 1);
        InsertRuleExample(RuleNo, Rule2, RuleDescription2, 1);
        InsertRuleExample(RuleNo, Rule3, RuleDescription3, 1);
        InsertRuleExample(RuleNo, Rule4, RuleDescription4, 1);
        InsertRuleExample(RuleNo, Rule5, RuleDescription5, 1);
        InsertRuleExample(RuleNo, Rule6, RuleDescription6, 1);
        InsertRuleExample(RuleNo, Rule7, RuleDescription7, 1);
        InsertRuleExample(RuleNo, Rule8, RuleDescription8, 1);
        InsertRuleExample(RuleNo, 'Line rules', 'Typical rules for line fields', 0);
        InsertRuleExample(RuleNo, Rule9, RuleDescription9, 1);
        InsertRuleExample(RuleNo, Rule10, RuleDescription10, 1);
        InsertRuleExample(RuleNo, Rule11, RuleDescription11, 1);
        InsertRuleExample(RuleNo, Rule12, RuleDescription12, 1);
        InsertRuleExample(RuleNo, Rule13, RuleDescription13, 1);
    end;

    procedure InsertRuleExample(var RuleNo: Integer; Rule: Text[100]; Description: Text[100]; Indentation: Integer)
    var
    begin
        RuleNo += 1;
        Rec."No." := PadStr('', 20 - StrLen(Format(RuleNo)), '0') + Format(RuleNo);
        Rec."Description 2" := Rule;
        Rec."Description" := Description;
        Rec."Statistics Group" := Indentation;
        Rec.Insert();
    end;


    var
        [InDataSet]
        IsBold: Boolean;
        Rule1: Label 'P[0-9]{8}', MaxLength = 50, Locked = true;
        RuleDescription1: Label 'Feldwert muss mit "P" beginnen, gefolgt von 8 Ziffern von 0 bis 9.', MaxLength = 100;
        Rule2: Label '[FR]-[0-9]{3,}', MaxLength = 50, Locked = true;
        RuleDescription2: Label 'Feldwert muss entweder mit "F" oder "R" und "-" beginnen, gefolgt von mindestens 3 Ziffern (0-9).', MaxLength = 100;
        Rule3: Label '[FR]-[0-9]{3,5}', MaxLength = 50, Locked = true;
        RuleDescription3: Label 'Der Feldwert muss entweder mit "F" oder "R" und "-" beginnen, gefolgt von 3 bis 5 Stellen (0-9).', MaxLength = 100;
        Rule4: Label 'I[0-9]{8}', MaxLength = 50, Locked = true;
        RuleDescription4: Label 'Feldwert muss mit "I" beginnen, gefolgt von 8 Ziffern von 0 bis 9.', MaxLength = 100;
        Rule5: Label 'RG[0-9]{5}X[0-1]{1}', MaxLength = 50, Locked = true;
        RuleDescription5: Label 'Der Feldwert muss mit "RG" beginnen, gefolgt von 5 Stellen, dann "X" gefolgt von 1 Stelle.', MaxLength = 100;
        Rule6: Label '<>ABC&<>DEF', MaxLength = 50, Locked = true;
        RuleDescription6: Label 'Der Feldwert darft nicht "ABC" und nicht "DEF" sein.', MaxLength = 100;
        Rule7: Label 'Rechnung|Gutschrift', MaxLength = 50, Locked = true;
        RuleDescription7: Label 'Feldwert muss entweder “Rechnung” oder “Gutschrift” sein.', MaxLength = 100;
        Rule8: Label '*AG*', MaxLength = 50, Locked = true;
        RuleDescription8: Label 'Der Feldwert muss die Zeichen “AG” enthalten.', MaxLength = 100;
        Rule9: Label 'Invoice', MaxLength = 50, Locked = true;
        RuleDescription9: Label 'Erkennt nur Zeilen, in denen das Feld das Wort Rechnung enthält.', MaxLength = 100;
        Rule10: Label 'Rechnung|Gutschrift', MaxLength = 50, Locked = true;
        RuleDescription10: Label 'Erkennt Zeilen in denen das Feld entweder das Wort "Rechnung" oder das Wort „Gutschrift“ enthält.', MaxLength = 100;
        Rule11: Label '<>Zwischensumme', MaxLength = 50, Locked = true;
        RuleDescription11: Label 'Zeilen überspringen, die das Wort "Zwischensumme" enthalten.', MaxLength = 100;
        Rule12: Label '<>Größe*', MaxLength = 50, Locked = true;
        RuleDescription12: Label 'Zeilen überspringen, in denen das Feld mit dem Wort "Größe" beginnt.', MaxLength = 100;
        Rule13: Label 'POS[0-9]{3}', MaxLength = 50, Locked = true;
        RuleDescription13: Label 'Filtert Zeilen in denen das Feld mit POS anfängt, gefolgt von 3 Ziffern im Bereich von 0-9', MaxLength = 100;

    //Rule: Label '', MaxLength = 50, Locked = true;
    //RuleDescription: Label '', MaxLength = 100;
}
