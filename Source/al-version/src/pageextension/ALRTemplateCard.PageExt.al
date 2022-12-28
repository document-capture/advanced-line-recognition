pageextension 61002 "ALR Template Card" extends "CDC Template Card"
{
    ContextSensitiveHelpPage = 'template-card';
    layout
    {
        addafter("Purch. Validate VAT Calc.")
        {
            field("ALR Line Validation Type"; Rec."ALR Line Validation Type")
            {
                ApplicationArea = All;
                ToolTip = 'Select if you want to use the default line validation from the template codeunit or the Adv. line recognition validation';
            }
            field(ALRValidateLineTotals; Rec."Validate Line Totals")
            {
                ApplicationArea = All;
                ToolTip = 'Select if you want to use validate the line totals against the net amount of the document';
                ObsoleteState = Pending;
                ObsoleteReason = 'Will be removed once the field is available in standard of Document Capture.';
            }
        }
        addafter("Purch. Validate VAT Calc.")
        {
            field("Auto PO search"; Rec."Auto PO search")
            {
                ToolTip = 'Enables the automatic search for purchase order numbers.';
                ApplicationArea = All;
            }
            field("Auto PO search filter"; Rec."Auto PO search filter")
            {
                ApplicationArea = All;
                ToolTip = 'Filter string that is used during automatic search for PO numbers.';
            }
        }
    }
}
