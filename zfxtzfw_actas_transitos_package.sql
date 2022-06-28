package zfxtzfw_actas_transitos authid current_user
is
    procedure Insert$(
        iclbRecord                      in  clob,
        oclbXML                         out clob);
    procedure Update$(
        iclbRecord                      in  clob,
        oclbXML                         out clob);
    procedure Create$FromXMLLst(
        iclbParam                       in  clob,
        oclbXML                         out clob);
    procedure Delete$(
        iclbRecord                      in      clob,
        oclbXML                         out     clob);
    procedure XQuery(
        iclbParam                       in      clob,
        oclbXML                         out     clob);
    procedure XActaTransito(
        iclbParam                       in      clob,
        oclbXML                         out     clob);
    procedure XActaTrnstoCrre(
        iclbParam                       in      clob,
        oclbXML                         out     clob);
end zfxtzfw_actas_transitos;