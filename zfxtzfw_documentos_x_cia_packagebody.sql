CREATE OR REPLACE PACKAGE BODY         ZFWEB."ZFXTZFW_DOCUMENTOS_X_CIA"
is
/****************************************************************************************

    NOMBRE:       zfstzfw_documentos_x_cia
    PROPOSITO:    Manejar todas las operaciones de la tabla de documentos por cia
                  Estado Corte.
    REVISION:
    Ver        Fecha       Autor              Descripcion
    ---------  ----------  ---------------    ------------------------------------
    1.0        20190205                       Creacion del paquete
    4.0        20190225    Guillermo Prieto   Modificacion del paquete para incluir la validacion
                                              para el desarrollo del Req 11: Reporte  Estado Planillas
                                              se debe validar que si se  digita la compania y el documento debe validar
                                              que ese documento corresponda a la compania, para esto se crea el
                                              procedimiento ValDoc_x_Cia.
                                              se debe validar que si se  digita el n�mero de formulario y el numero de documento,
                                              debe validar que ese documento corresponda al formulario, para esto se crea el
                                              procedimiento ValDoc_x_Fmm.
                                              se debe validar que si se  digita la compania, el n�mero de formulario y el numero de documento,
                                              debe validar que los tres correspondan al formulario, para esto se crea el
                                              procedimiento ValDoc_x_Fmm_x_Cia.
   5.0         20191212    Guillermo Prieto   Modificacion del paquete para odificar el procedimiento XUsuClficadoRegDoc 
                                              para incluir los dos campos nuevos: nmdoctransportedian y sngrab_autom_dian 
                                              para que desde la aplicacion se pueda saber cuales documentos por 
                                              compania fueron precargados por el nuevo desarrollo
                                              de planillas de envio de la dian para precargar la informacion de 
                                              acuerdo a la historia de usuario 5 del documento
                                              F01-PS030223 Levantamiento de Requisitos Planilla de Envio
                                              CC17  DLLO06                                                                                            
*****************************************************************************************/
-- Tipos/subtipos registro
    subtype rtytzfw_documentos_x_cia                is zfstzfw_documentos_x_cia.rtytzfw_documentos_x_cia;
    subtype pttyXML                                is zfx_library.gttyXML;
    subtype rtytzfw_transitos_documentos            is zfstzfw_transitos_documentos.rtytzfw_transitos_documentos;

-- Tipos tabla
     type prtyNew is record(
        vchTag  varchar2(30),
        vchData varchar2(128));
    type pttyNew is table of prtyNew
        index by binary_integer;
-- Variables
    ptblNew     pttyNew;
-- Constantes
   cvhNotNull   constant varchar2(2) := 'NN';
-- Excepciones
-- Procedimientos
-- Funciones
--------------------------------------------------- Create$FromXMLLst.prc ---------------------------------------------
procedure Create$FromXMLLst(
    iclbParam           in clob,
    oclbXML             out clob)
is
    xmlParam            xmltype;
    xmlTab              xmltype;
    xmlTab1             xmltype;
    nmbCont             number;
    vchAction           varchar2(15);
    clbRowSrc           clob;
    clbRowSet           clob;
    clbRowSetMsg        clob;
    clbMessage          clob;
    nmbMsgCode          number;
    vchMsgDesc          varchar2(256);
    blnRowsErr          boolean;
    blnRowErr           boolean;
    nmbNew              number;
--=====================================================================================================================
procedure InsertTable$(
    ivchTag             in varchar2,
    ivchValue           in varchar2)
is
begin
    nmbNew                  := nmbNew +1;
    ptblNew(nmbNew).vchTag  := ivchTag;
    ptblNew(nmbNew).vchData := '<' || ivchTag || '>' || ivchValue || '</' || ivchTag || '>';
end InsertTable$;
------------------------------------------------------------------------------------------------------------------------
procedure ConcatMsg$
is
begin
    clbRowSrc := zfx_library.ConcatTagValue(clbRowSrc,'ROW','MSGDESCRIPTION',vchMsgDesc);
    clbRowSrc := zfx_library.ConcatTagValue(clbRowSrc,'ROW','MSGCODE',nmbMsgCode);
end ConcatMsg$;
------------------------------------------------------------------------------------------------------------------------
function LookupErr$
return boolean
is
    xmlMessage xmltype;
begin
    nmbMsgCode := null;
    vchMsgDesc := null;
    if (clbMessage is not null) then
        xmlMessage := xmltype(clbMessage);
        nmbMsgCode := zfx_library.fnmbgetNumber4XML(xmlMessage,'CODE');
        vchMsgDesc := zfx_library.fvchgetString4XML(xmlMessage,'DESCRIPTION','N');
    end if;
    return(nmbMsgCode is not null and nmbMsgCode <> 7);
end LookupErr$;
--=====================================================================================================================
begin
    xmlParam := xmltype(iclbParam);
    xmlTab := xmlParam.extract('/ROWSET');
    nmbCont := 1;
    nmbNew := 0;
    blnRowsErr := false;
    While(xmlTab.existsnode('//ROW[' || nmbCont || ']') = 1)
    loop
        zfx_library.XmlOpen$(xmlTab,'//ROW[' || nmbCont || ']',xmlTab1);
        clbMessage := null;
        clbRowSrc := xmltab1.getClobVal;
        zfx_library.XmlValue$(xmlTab1,'/ROW/DBX_ACTION/text()',cvhNotNull,vchAction);
        case vchAction
             when 'CREATE' then clbRowSet := '<ROWSET>'||clbRowSrc||'</ROWSET>';
                    zfxtzfw_documentos_x_cia.Insert$(clbRowSet,clbMessage);
             when 'UPDATE' then clbRowSet := '<ROWSET>'||clbRowSrc||'</ROWSET>';
                    zfxtzfw_documentos_x_cia.Update$(clbRowSet,clbMessage);
             when 'DELETE' then clbRowSet := '<ROWSET>'||clbRowSrc||'</ROWSET>';
                    zfxtzfw_documentos_x_cia.Delete$(clbRowSet,clbMessage);
             else null;
        end case;
        blnRowErr := LookupErr$;
        blnRowsErr := blnRowErr or blnRowsErr;
        ConcatMsg$;
        clbRowsetMsg := clbRowsetMsg || clbRowSrc;
        nmbCont := nmbCont +1;
    End loop;
    if (not blnRowsErr) then
        commit;
        ptblNew.delete;
        clbRowsetMsg := '<ROWSET>' || clbRowsetMsg ||'</ROWSET>'||chr(10);
        oclbXML := replace(clbRowsetMsg, '<DBX_ACTION>CREATE</DBX_ACTION>',
                                         '<DBX_ACTION>NONE</DBX_ACTION>');
        return;
    end if;
    Rollback;
    clbRowsetMsg := '<ROWSET>' || clbRowsetMsg ||'</ROWSET>'||chr(10);
    oclbXML := clbRowsetMsg;
    return;
end Create$fromxmllst;
--------------------------------------------------- UsuCalDsprcinteXMLLst.prc ---------------------------------------------
procedure UsuCalDsprcinteXMLLst(
    iclbParam           in clob,
    oclbXML             out clob)
is
    xmlParam            xmltype;
    xmlTab              xmltype;
    xmlTab1             xmltype;
    nmbCont             number;
    vchAction           varchar2(30);
    clbRowSrc           clob;
    clbRowSet           clob;
    clbRowSetMsg        clob;
    clbMessage          clob;
    nmbMsgCode          number;
    vchMsgDesc          varchar2(256);
    blnRowsErr          boolean;
    blnRowErr           boolean;
    nmbNew              number;
--=====================================================================================================================
procedure InsertTable$(
    ivchTag             in varchar2,
    ivchValue           in varchar2)
is
begin
    nmbNew                  := nmbNew +1;
    ptblNew(nmbNew).vchTag  := ivchTag;
    ptblNew(nmbNew).vchData := '<' || ivchTag || '>' || ivchValue || '</' || ivchTag || '>';
end InsertTable$;
------------------------------------------------------------------------------------------------------------------------
procedure ConcatMsg$
is
begin
    clbRowSrc := zfx_library.ConcatTagValue(clbRowSrc,'ROW','MSGDESCRIPTION',vchMsgDesc);
    clbRowSrc := zfx_library.ConcatTagValue(clbRowSrc,'ROW','MSGCODE',nmbMsgCode);
end ConcatMsg$;
------------------------------------------------------------------------------------------------------------------------
function LookupErr$
return boolean
is
    xmlMessage xmltype;
begin
    nmbMsgCode := null;
    vchMsgDesc := null;
    if (clbMessage is not null) then
        xmlMessage := xmltype(clbMessage);
        nmbMsgCode := zfx_library.fnmbgetNumber4XML(xmlMessage,'CODE');
        vchMsgDesc := zfx_library.fvchgetString4XML(xmlMessage,'DESCRIPTION','N');
    end if;
    return(nmbMsgCode is not null and nmbMsgCode <> 7);
end LookupErr$;
--=====================================================================================================================
begin
    xmlParam := xmltype(iclbParam);
    xmlTab := xmlParam.extract('/ROWSET');
    nmbCont := 1;
    nmbNew := 0;
    blnRowsErr := false;
    While(xmlTab.existsnode('//ROW[' || nmbCont || ']') = 1)
    loop
        zfx_library.XmlOpen$(xmlTab,'//ROW[' || nmbCont || ']',xmlTab1);
        clbMessage := null;
        clbRowSrc := xmltab1.getClobVal;
        zfx_library.XmlValue$(xmlTab1,'/ROW/DBX_ACTION/text()',cvhNotNull,vchAction);
        case vchAction
             when 'UPDATE' then clbRowSet := '<ROWSET>'||clbRowSrc||'</ROWSET>';
                    zfxtzfw_documentos_x_cia.UpdateUsuClfcdoDsprcinte(clbRowSet,clbMessage);
             else null;
        end case;
        blnRowErr := LookupErr$;
        blnRowsErr := blnRowErr or blnRowsErr;
        ConcatMsg$;
        clbRowsetMsg := clbRowsetMsg || clbRowSrc;
        nmbCont := nmbCont +1;
    End loop;
    if (not blnRowsErr) then
        commit;
        ptblNew.delete;
        clbRowsetMsg := '<ROWSET>' || clbRowsetMsg ||'</ROWSET>'||chr(10);
        oclbXML := clbRowsetMsg;
        return;
    end if;
    Rollback;
    clbRowsetMsg := '<ROWSET>' || clbRowsetMsg ||'</ROWSET>'||chr(10);
    oclbXML := clbRowsetMsg;
    return;
end UsuCalDsprcinteXMLLst;
--------------------------------------------------- UsuCalInventarioXMLLst.prc ---------------------------------------------
procedure UsuCalInventarioXMLLst(
    iclbParam           in clob,
    oclbXML             out clob)
is
    xmlParam            xmltype;
    xmlTab              xmltype;
    xmlTab1             xmltype;
    nmbCont             number;
    vchAction           varchar2(30);
    clbRowSrc           clob;
    clbRowSet           clob;
    clbRowSetMsg        clob;
    clbMessage          clob;
    nmbMsgCode          number;
    vchMsgDesc          varchar2(256);
    blnRowsErr          boolean;
    blnRowErr           boolean;
    nmbNew              number;
--=====================================================================================================================
procedure InsertTable$(
    ivchTag             in varchar2,
    ivchValue           in varchar2)
is
begin
    nmbNew                  := nmbNew +1;
    ptblNew(nmbNew).vchTag  := ivchTag;
    ptblNew(nmbNew).vchData := '<' || ivchTag || '>' || ivchValue || '</' || ivchTag || '>';
end InsertTable$;
------------------------------------------------------------------------------------------------------------------------
procedure ConcatMsg$
is
begin
    clbRowSrc := zfx_library.ConcatTagValue(clbRowSrc,'ROW','MSGDESCRIPTION',vchMsgDesc);
    clbRowSrc := zfx_library.ConcatTagValue(clbRowSrc,'ROW','MSGCODE',nmbMsgCode);
end ConcatMsg$;
------------------------------------------------------------------------------------------------------------------------
function LookupErr$
return boolean
is
    xmlMessage xmltype;
begin
    nmbMsgCode := null;
    vchMsgDesc := null;
    if (clbMessage is not null) then
        xmlMessage := xmltype(clbMessage);
        nmbMsgCode := zfx_library.fnmbgetNumber4XML(xmlMessage,'CODE');
        vchMsgDesc := zfx_library.fvchgetString4XML(xmlMessage,'DESCRIPTION','N');
    end if;
    return(nmbMsgCode is not null and nmbMsgCode <> 7);
end LookupErr$;
--=====================================================================================================================
begin
    xmlParam := xmltype(iclbParam);
    xmlTab := xmlParam.extract('/ROWSET');
    nmbCont := 1;
    nmbNew := 0;
    blnRowsErr := false;
    While(xmlTab.existsnode('//ROW[' || nmbCont || ']') = 1)
    loop
        zfx_library.XmlOpen$(xmlTab,'//ROW[' || nmbCont || ']',xmlTab1);
        clbMessage := null;
        clbRowSrc := xmltab1.getClobVal;
        zfx_library.XmlValue$(xmlTab1,'/ROW/DBX_ACTION/text()',cvhNotNull,vchAction);
        case vchAction
             when 'UPDATE' then clbRowSet := '<ROWSET>'||clbRowSrc||'</ROWSET>';
                    zfxtzfw_documentos_x_cia.UpdateUsuCalificado(clbRowSet,clbMessage);
             else null;
        end case;
        blnRowErr := LookupErr$;
        blnRowsErr := blnRowErr or blnRowsErr;
        ConcatMsg$;
        clbRowsetMsg := clbRowsetMsg || clbRowSrc;
        nmbCont := nmbCont +1;
    End loop;
    if (not blnRowsErr) then
        commit;
        ptblNew.delete;
        clbRowsetMsg := '<ROWSET>' || clbRowsetMsg ||'</ROWSET>'||chr(10);
        oclbXML := clbRowsetMsg;
        return;
    end if;
    Rollback;
    clbRowsetMsg := '<ROWSET>' || clbRowsetMsg ||'</ROWSET>'||chr(10);
    oclbXML := clbRowsetMsg;
    return;
end UsuCalInventarioXMLLst;
--------------------------------------------------- UpdVerificarTransXMLLst.prc ---------------------------------------------
procedure UpdVerificarTransXMLLst(
    iclbParam           in clob,
    oclbXML             out clob)
is
    xmlParam            xmltype;
    xmlTab              xmltype;
    xmlTab1             xmltype;
    nmbCont             number;
    vchAction           varchar2(30);
    clbRowSrc           clob;
    clbRowSet           clob;
    clbRowSetMsg        clob;
    clbMessage          clob;
    nmbMsgCode          number;
    vchMsgDesc          varchar2(256);
    blnRowsErr          boolean;
    blnRowErr           boolean;
    nmbNew              number;
--=====================================================================================================================
procedure InsertTable$(
    ivchTag             in varchar2,
    ivchValue           in varchar2)
is
begin
    nmbNew                  := nmbNew +1;
    ptblNew(nmbNew).vchTag  := ivchTag;
    ptblNew(nmbNew).vchData := '<' || ivchTag || '>' || ivchValue || '</' || ivchTag || '>';
end InsertTable$;
------------------------------------------------------------------------------------------------------------------------
procedure ConcatMsg$
is
begin
    clbRowSrc := zfx_library.ConcatTagValue(clbRowSrc,'ROW','MSGDESCRIPTION',vchMsgDesc);
    clbRowSrc := zfx_library.ConcatTagValue(clbRowSrc,'ROW','MSGCODE',nmbMsgCode);
end ConcatMsg$;
------------------------------------------------------------------------------------------------------------------------
function LookupErr$
return boolean
is
    xmlMessage xmltype;
begin
    nmbMsgCode := null;
    vchMsgDesc := null;
    if (clbMessage is not null) then
        xmlMessage := xmltype(clbMessage);
        nmbMsgCode := zfx_library.fnmbgetNumber4XML(xmlMessage,'CODE');
        vchMsgDesc := zfx_library.fvchgetString4XML(xmlMessage,'DESCRIPTION','N');
    end if;
    return(nmbMsgCode is not null and nmbMsgCode <> 7);
end LookupErr$;
--=====================================================================================================================
begin
    xmlParam := xmltype(iclbParam);
    xmlTab := xmlParam.extract('/ROWSET');
    nmbCont := 1;
    nmbNew := 0;
    blnRowsErr := false;
    While(xmlTab.existsnode('//ROW[' || nmbCont || ']') = 1)
    loop
        zfx_library.XmlOpen$(xmlTab,'//ROW[' || nmbCont || ']',xmlTab1);
        clbMessage := null;
        clbRowSrc := xmltab1.getClobVal;
        zfx_library.XmlValue$(xmlTab1,'/ROW/DBX_ACTION/text()',cvhNotNull,vchAction);
        case vchAction
             when 'UPDATE' then clbRowSet := '<ROWSET>'||clbRowSrc||'</ROWSET>';
                    zfxtzfw_documentos_x_cia.UpdVerificarTransito(clbRowSet,clbMessage);
             else null;
        end case;
        blnRowErr := LookupErr$;
        blnRowsErr := blnRowErr or blnRowsErr;
        ConcatMsg$;
        clbRowsetMsg := clbRowsetMsg || clbRowSrc;
        nmbCont := nmbCont +1;
    End loop;
    if (not blnRowsErr) then
        commit;
        ptblNew.delete;
        clbRowsetMsg := '<ROWSET>' || clbRowsetMsg ||'</ROWSET>'||chr(10);
        oclbXML := clbRowsetMsg;
        return;
    end if;
    Rollback;
    clbRowsetMsg := '<ROWSET>' || clbRowsetMsg ||'</ROWSET>'||chr(10);
    oclbXML := clbRowsetMsg;
    return;
end UpdVerificarTransXMLLst;
------------------------------------------------------ Insert$.prc ----------------------------------------------------
procedure Insert$(
    iclbRecord          in      clob,
    oclbXML             out     clob)
is
    rcrRecord          rtytzfw_documentos_x_cia;
    nmbErr             number;
    vchErrMsg          varchar2(256);
    xmlRecord          xmltype;

    rcrRecordTrandoc           rtytzfw_transitos_documentos;
    vchcdplaca                 tzfw_transitos_documentos.cdplaca%type;
    dtfeingreso                tzfw_transitos_documentos.feingreso%type;
    vchcdcia_usuaria           tzfw_transitos_documentos.cdcia_usuaria%type;
    nmbnmtransito_documento    tzfw_transitos_documentos.nmtransito_documento%type;
    vchcdtipo_documento        tzfw_transitos_documentos.cdtipo_documento%type;
    vchnmdoctransporte         tzfw_transitos_documentos.nmdoctransporte%type;
    vchsngranel_nal            tzfw_transitos_documentos.sngranel_nal%type;
    vchsnparcial               tzfw_documentos_x_cia.snparcial%type;
    vchnacional                tzfw_tipos_ingreso.nacional%type  := 'N';
    nmbActuaExi                number := 0;
    vchnmformulario_zf         tzfw_documentos_x_cia.nmformulario_zf%type;

   Cursor  cuTipos_ingreso (ipvchcdtipo_documento  TZFW_TRANSITOS_DOCUMENTOS.CDTIPO_DOCUMENTO%type) is
   select  m.nacional nacional
   from    TZFW_TIPOS_INGRESO m
   where   m.cdtipo_ingreso = ipvchcdtipo_documento
   and    rownum = 1;

begin
/****************************************************************************************
    3.0        20190312    Guillermo Prieto   Modificacion del paquete para incluir los campos de entrega parcial y granel
                                              nacional de   acuerdo a lo solicitado en el req 7 Parametro Dias ingreso Graneles
                                              Nacionales del documento
                                              F02-PS030223 Especificacion de Requisitos Mejoras 2147 (Planillas).docx.
                                              Adicionando el campo SNGRANEL_NAL
*****************************************************************************************/
/****************************************************************************************
   5.0         20191213    Guillermo Prieto   Modificacion del paquete para odificar el procedimiento XUsuClficadoRegDoc 
                                              para incluir los dos campos nuevos: nmdoctransportedian y sngrab_autom_dian 
                                              para que desde la aplicacion se pueda saber cuales documentos por 
                                              compania fueron precargados por el nuevo desarrollo
                                              de planillas de envio de la dian para precargar la informacion de 
                                              acuerdo a la historia de usuario 5 del documento
                                              F01-PS030223 Levantamiento de Requisitos Planilla de Envio
                                              CC17  DLLO06                                              
*****************************************************************************************/

    xmlRecord := xmltype(iclbRecord);

    rcrRecord.cdplaca                       := zfx_library.fvchgetString4XML(xmlRecord,'CDPLACA');
    rcrRecord.feingreso                     := zfx_library.fdtegetDate4XML(xmlRecord,  'FEINGRESO');
    rcrRecord.cdcia_usuaria                 := zfx_library.fvchgetString4XML(xmlRecord,'CDCIA_USUARIA');
    rcrRecord.nmtransito_documento          := zfx_library.fnmbgetNumber4XML(xmlRecord,'NMTRANSITO_DOCUMENTO');
    rcrRecord.nmconsecutivo_doc             := zfx_library.fnmbgetNumber4XML(xmlRecord,'NMCONSECUTIVO_DOC');
    rcrRecord.nmcontenedores                := zfx_library.fvchgetString4XML(xmlRecord,'NMCONTENEDORES');
    rcrRecord.snsol_desprecinte             := zfx_library.fvchgetString4XML(xmlRecord,'SNSOL_DESPRECINTE');
    rcrRecord.sndesprecinte                 := zfx_library.fvchgetString4XML(xmlRecord,  'SNDESPRECINTE');
    rcrRecord.sninventario                  := zfx_library.fvchgetString4XML(xmlRecord,'SNINVENTARIO');
    rcrRecord.nmguia_bl_dex                 := zfx_library.fvchgetString4XML(xmlRecord,'NMGUIA_BL_DEX');
    rcrRecord.nmbultos_rel                  := zfx_library.fnmbgetNumber4XML(xmlRecord,  'NMBULTOS_REL');
    rcrRecord.nmbultos_rec                  := zfx_library.fnmbgetNumber4XML(xmlRecord,'NMBULTOS_REC');
    rcrRecord.nmbultos_pla                  := zfx_library.fnmbgetNumber4XML(xmlRecord,'NMBULTOS_PLA');
    rcrRecord.nmpeso_rel                    := zfx_library.fnmbgetNumber4XML(xmlRecord,'NMPESO_REL');
    rcrRecord.nmpeso_rec                    := zfx_library.fnmbgetNumber4XML(xmlRecord,'NMPESO_REC');
    rcrRecord.nmpeso_pla                    := zfx_library.fnmbgetNumber4XML(xmlRecord,'NMPESO_PLA');
    rcrRecord.nmformulario_zf               := zfx_library.fvchgetString4XML(xmlRecord,  'NMFORMULARIO_ZF');
    rcrRecord.cditem                        := zfx_library.fvchgetString4XML(xmlRecord,'CDITEM');
    rcrRecord.cdtransportadora              := zfx_library.fvchgetString4XML(xmlRecord,'CDTRANSPORTADORA');
    rcrRecord.cdtipo_mercancia              := zfx_library.fnmbgetNumber4XML(xmlRecord,'CDTIPO_MERCANCIA');
    rcrRecord.lsclase_mcia                  := zfx_library.fvchgetString4XML(xmlRecord,'LSCLASE_MCIA');
    rcrRecord.lsestado_mcia                 := zfx_library.fvchgetString4XML(xmlRecord,'LSESTADO_MCIA');
    rcrRecord.cdtipo_precinto               := zfx_library.fvchgetString4XML(xmlRecord,  'CDTIPO_PRECINTO');
    rcrRecord.dsprecinto                    := zfx_library.fvchgetString4XML(xmlRecord,'DSPRECINTO');
    rcrRecord.dsobservacion                 := zfx_library.fvchgetString4XML(xmlRecord,'DSOBSERVACION');
    rcrRecord.fesol_desprecinte             := zfx_library.fdtegetDate4XML(xmlRecord,  'FESOL_DESPRECINTE');
    rcrRecord.cdusuario_soldesprecinte      := zfx_library.fvchgetString4XML(xmlRecord,'CDUSUARIO_SOLDESPRECINTE');
    rcrRecord.fedesprecinte                 := zfx_library.fdtegetDate4XML(xmlRecord,'FEDESPRECINTE');
    rcrRecord.cdusuario_desprecinte         := zfx_library.fvchgetString4XML(xmlRecord,'CDUSUARIO_DESPRECINTE');
    rcrRecord.feinventario                  := zfx_library.fdtegetDate4XML(xmlRecord,'FEINVENTARIO');
    rcrRecord.cdusuario_inventario          := zfx_library.fvchgetString4XML(xmlRecord,'CDUSUARIO_INVENTARIO');
    rcrRecord.sninconsistencia              := zfx_library.fvchgetString4XML(xmlRecord,'SNINCONSISTENCIA');
    rcrRecord.nmdocumento                   := zfx_library.fvchgetString4XML(xmlRecord,'NMDOCUMENTO');
    rcrRecord.dsmercancia                   := zfx_library.fvchgetString4XML(xmlRecord,'DSMERCANCIA');
    rcrRecord.nmtara_contenedor             := zfx_library.fnmbgetNumber4XML(xmlRecord,'NMTARA_CONTENEDOR');
    rcrRecord.cdusuario_reg                 := zfx_library.fvchgetString4XML(xmlRecord,'CDUSUARIO_REG');
    rcrRecord.cdusuario_aud                 := zfx_library.fvchGetString4XML(xmlRecord,  'CDUSUARIO_AUD');
    rcrRecord.fedescargue                   :=sysdate;
    rcrRecord.snparcial                     := zfx_library.fvchGetString4XML(xmlRecord,  'SNPARCIAL');
    vchsngranel_nal                         := zfx_library.fvchgetString4XML(xmlRecord,'SNGRANEL_NAL');
    vchcdtipo_documento                     := zfx_library.fvchgetString4XML(xmlRecord,'CDTIPO_DOCUMENTO');
    vchnmdoctransporte                      := zfx_library.fvchgetString4XML(xmlRecord,'NMDOCTRANSPORTE');
    rcrRecord.dsinconsistencias             := zfx_library.fvchGetString4XML(xmlRecord,  'DSINCONSISTENCIAS');
    rcrRecord.nmdoctransportedian           := zfx_library.fvchGetString4XML(xmlRecord,  'NMDOCTRANSPORTEDIAN');
    rcrRecord.sngrab_autom_dian             := zfx_library.fvchGetString4XML(xmlRecord,  'SNGRAB_AUTOM_DIAN');
    

    /*  zfstzfw_documentos_x_cia.ValidarFormulario(nmbErr, rcrRecord.cdcia_usuaria, rcrRecord.nmformulario_zf,rcrRecord.id);

    if (nmbErr is not null) then
        Rollback;
        oclbXML := zfx_library.fclbsetMessage2XML(nmbErr, 'El formulario ya esta asociado a otro documento por compa�ia');
        return;
    end if;
    */

    vchcdplaca                 := zfx_library.fvchgetString4XML(xmlRecord,'CDPLACA');
    dtfeingreso                := zfx_library.fdtegetDate4XML(xmlRecord,  'FEINGRESO');
    vchcdcia_usuaria           := zfx_library.fvchgetString4XML(xmlRecord,'CDCIA_USUARIA');
    nmbnmtransito_documento    := zfx_library.fnmbgetNumber4XML(xmlRecord,'NMTRANSITO_DOCUMENTO');
    vchcdtipo_documento        := zfx_library.fvchgetString4XML(xmlRecord,'CDTIPO_DOCUMENTO');
    vchnmdoctransporte         := zfx_library.fvchgetString4XML(xmlRecord,'NMDOCTRANSPORTE');
    vchsngranel_nal            := zfx_library.fvchgetString4XML(xmlRecord,'SNGRANEL_NAL');
    vchsnparcial               := zfx_library.fvchGetString4XML(xmlRecord,'SNPARCIAL');
    vchnmformulario_zf         := zfx_library.fvchgetString4XML(xmlRecord,  'NMFORMULARIO_ZF');

    rcrRecordTrandoc.cdplaca               := vchcdplaca;
    rcrRecordTrandoc.feingreso             := dtfeingreso;
    rcrRecordTrandoc.cdcia_usuaria         := vchcdcia_usuaria;
    rcrRecordTrandoc.nmtransito_documento  := nmbnmtransito_documento;
    rcrRecordTrandoc.cdtipo_documento      := vchcdtipo_documento;
    rcrRecordTrandoc.nmdoctransporte       := vchnmdoctransporte;
    rcrRecordTrandoc.sngranel_nal          := vchsngranel_nal;

    open   cuTipos_ingreso (vchcdtipo_documento) ;
    fetch  cuTipos_ingreso into vchnacional;
    close  cuTipos_ingreso;


    zfitzfw_documentos_x_cia.Insert$(nmbErr, vchErrMsg, rcrRecord);

    if vchnacional = 'S' then
       null;
       --ejecutar procedimiento en S que actualice granel nal y entrega parcial
       zfstzfw_documentos_x_cia.Actual_granel_y_o_parcial(nmbErr, vchErrMsg, rcrRecordTrandoc, vchsnparcial, vchnmformulario_zf, nmbActuaExi);
    end if;

    if (nmbErr is not null) then
        Rollback;
        oclbXML := zfx_library.fclbsetMessage2XML(nmbErr, vchErrMsg);
        return;
    end if;

    commit;
    vchErrMsg := 'Operacion se completo con exito.';
    oclbXML := zfx_library.fclbsetMessage2XML(7, vchErrMsg);
    return;
end Insert$;
------------------------------------------------------ Update$.prc ----------------------------------------------------
procedure Update$(
    iclbRecord          in      clob,
    oclbXML             out     clob)
is
    rcrRecord           rtytzfw_documentos_x_cia;
    nmbErr              number;
    vchErrMsg           varchar2(256);
    cdusuario_ab        tzfw_documentos_x_cia.cdusuario_reg%type;
    vnmplanilla         tzfw_estados_planilla.nmplanilla%type;
    vcdestado           tzfw_estados_planilla.cdestado%type;
    vchCsc              tzfw_estados_planilla.cdcsc%type;
    vdsplanilla         tzfw_estados_planilla.dsplanilla%type;
    usuario             varchar2(20);
    xmlRecord           xmltype;

    rcrRecordTrandoc           rtytzfw_transitos_documentos;
    vchcdplaca                 tzfw_transitos_documentos.cdplaca%type;
    dtfeingreso                tzfw_transitos_documentos.feingreso%type;
    vchcdcia_usuaria           tzfw_transitos_documentos.cdcia_usuaria%type;
    nmbnmtransito_documento    tzfw_transitos_documentos.nmtransito_documento%type;
    vchcdtipo_documento        tzfw_transitos_documentos.cdtipo_documento%type;
    vchnmdoctransporte         tzfw_transitos_documentos.nmdoctransporte%type;
    vchsngranel_nal            tzfw_transitos_documentos.sngranel_nal%type;
    vchsnparcial               tzfw_documentos_x_cia.snparcial%type;
    vchnacional                tzfw_tipos_ingreso.nacional%type  := 'N';
    nmbActuaExi                number := 0;
    vchnmformulario_zf         tzfw_documentos_x_cia.nmformulario_zf%type;

   Cursor  cuTipos_ingreso (ipvchcdtipo_documento  TZFW_TRANSITOS_DOCUMENTOS.CDTIPO_DOCUMENTO%type) is
   select  m.nacional nacional
   from    TZFW_TIPOS_INGRESO m
   where   m.cdtipo_ingreso = ipvchcdtipo_documento
   and    rownum = 1;

begin
/****************************************************************************************
    3.0        20190312    Guillermo Prieto   Modificacion del paquete para incluir los campos de entrega parcial y granel
                                              nacional de   acuerdo a lo solicitado en el req 7 Parametro Dias ingreso Graneles
                                              Nacionales del documento
                                              F02-PS030223 Especificacion de Requisitos Mejoras 2147 (Planillas).docx.
                                              Adicionando el campo SNGRANEL_NAL
*****************************************************************************************/

    xmlRecord := xmltype(iclbRecord);
    --insert into tmp_prueba values (iclbRecord,sysdate);
    --commit;

    rcrRecord.cdplaca                       := zfx_library.fvchgetString4XML(xmlRecord,'CDPLACA');
    rcrRecord.feingreso                     := zfx_library.fdtegetDate4XML(xmlRecord,  'FEINGRESO');
    rcrRecord.cdcia_usuaria                 := zfx_library.fvchgetString4XML(xmlRecord,'CDCIA_USUARIA');
    rcrRecord.nmtransito_documento          := zfx_library.fnmbgetNumber4XML(xmlRecord,'NMTRANSITO_DOCUMENTO');
    rcrRecord.nmconsecutivo_doc             := zfx_library.fnmbgetNumber4XML(xmlRecord,'NMCONSECUTIVO_DOC');
    rcrRecord.nmcontenedores                := zfx_library.fvchgetString4XML(xmlRecord,'NMCONTENEDORES');
    rcrRecord.snsol_desprecinte             := zfx_library.fvchgetString4XML(xmlRecord,'SNSOL_DESPRECINTE');
    rcrRecord.sndesprecinte                 := zfx_library.fvchgetString4XML(xmlRecord,'SNDESPRECINTE');
    rcrRecord.sninventario                  := zfx_library.fvchgetString4XML(xmlRecord,'SNINVENTARIO');
    rcrRecord.nmguia_bl_dex                 := zfx_library.fvchgetString4XML(xmlRecord,'NMGUIA_BL_DEX');
    rcrRecord.nmbultos_rel                  := zfx_library.fnmbgetNumber4XML(xmlRecord,'NMBULTOS_REL');
    rcrRecord.nmbultos_rec                  := zfx_library.fnmbgetNumber4XML(xmlRecord,'NMBULTOS_REC');
    rcrRecord.nmbultos_pla                  := zfx_library.fnmbgetNumber4XML(xmlRecord,'NMBULTOS_PLA');
    rcrRecord.nmpeso_rel                    := zfx_library.fnmbgetNumber4XML(xmlRecord,'NMPESO_REL');
    rcrRecord.nmpeso_rec                    := zfx_library.fnmbgetNumber4XML(xmlRecord,'NMPESO_REC');
    rcrRecord.nmpeso_pla                    := zfx_library.fnmbgetNumber4XML(xmlRecord,'NMPESO_PLA');
    rcrRecord.nmformulario_zf               := zfx_library.fvchgetString4XML(xmlRecord,'NMFORMULARIO_ZF');
    rcrRecord.cditem                        := zfx_library.fvchgetString4XML(xmlRecord,'CDITEM');
    rcrRecord.cdtransportadora              := zfx_library.fvchgetString4XML(xmlRecord,'CDTRANSPORTADORA');
    rcrRecord.cdtipo_mercancia              := zfx_library.fnmbgetNumber4XML(xmlRecord,'CDTIPO_MERCANCIA');
    rcrRecord.lsclase_mcia                  := zfx_library.fvchgetString4XML(xmlRecord,'LSCLASE_MCIA');
    rcrRecord.lsestado_mcia                 := zfx_library.fvchgetString4XML(xmlRecord,'LSESTADO_MCIA');
    rcrRecord.cdtipo_precinto               := zfx_library.fvchgetString4XML(xmlRecord,'CDTIPO_PRECINTO');
    rcrRecord.dsprecinto                    := zfx_library.fvchgetString4XML(xmlRecord,'DSPRECINTO');
    rcrRecord.dsobservacion                 := zfx_library.fvchgetString4XML(xmlRecord,'DSOBSERVACION');
    rcrRecord.fesol_desprecinte             := zfx_library.fdtegetDate4XML(xmlRecord,  'FESOL_DESPRECINTE');
    rcrRecord.cdusuario_soldesprecinte      := zfx_library.fvchgetString4XML(xmlRecord,'CDUSUARIO_SOLDESPRECINTE');
    rcrRecord.fedesprecinte                 := zfx_library.fdtegetDate4XML(xmlRecord,'FEDESPRECINTE');
    rcrRecord.cdusuario_desprecinte         := zfx_library.fvchgetString4XML(xmlRecord,'CDUSUARIO_DESPRECINTE');
    rcrRecord.feinventario                  := zfx_library.fdtegetDate4XML(xmlRecord,'FEINVENTARIO');
    rcrRecord.cdusuario_inventario          := zfx_library.fvchgetString4XML(xmlRecord,'CDUSUARIO_INVENTARIO');
    rcrRecord.sninconsistencia              := zfx_library.fvchgetString4XML(xmlRecord,'SNINCONSISTENCIA');
    rcrRecord.nmdocumento                   := zfx_library.fvchgetString4XML(xmlRecord,'NMDOCUMENTO');
    rcrRecord.dsmercancia                   := zfx_library.fvchgetString4XML(xmlRecord,'DSMERCANCIA');
    rcrRecord.nmtara_contenedor             := zfx_library.fnmbgetNumber4XML(xmlRecord,'NMTARA_CONTENEDOR');
    rcrRecord.cdusuario_reg                 := zfx_library.fvchgetString4XML(xmlRecord,'CDUSUARIO_REG');
    rcrRecord.id                            := zfx_library.fnmbgetNumber4XML(xmlRecord, 'ID');
    rcrRecord.cdusuario_aud                 := zfx_library.fvchGetString4XML(xmlRecord,  'CDUSUARIO_AUD');
    cdusuario_ab                            := zfx_library.fvchgetString4XML(xmlRecord,  'CDUSUARIO_AB');
    vnmplanilla                             := zfx_library.fvchGetString4XML(xmlRecord,  'NMPLANILLA');
    vchCsc                                  := zfx_library.fvchGetString4XML(xmlRecord,  'CDCSC');
    vcdestado                               := zfx_library.fvchGetString4XML(xmlRecord,  'CDPLANILLA');
    vdsplanilla                             := zfx_library.fvchGetString4XML(xmlRecord,  'DSPLANILLA');
    rcrRecord.snparcial                     := zfx_library.fvchGetString4XML(xmlRecord,  'SNPARCIAL');
    vchsngranel_nal                         := zfx_library.fvchgetString4XML(xmlRecord,'SNGRANEL_NAL');
    vchcdtipo_documento                     := zfx_library.fvchgetString4XML(xmlRecord,'CDTIPO_DOCUMENTO');
    vchnmdoctransporte                      := zfx_library.fvchgetString4XML(xmlRecord,'NMDOCTRANSPORTE');
    rcrRecord.dsinconsistencias             := zfx_library.fvchGetString4XML(xmlRecord,  'DSINCONSISTENCIAS');

    vchcdplaca                 := zfx_library.fvchgetString4XML(xmlRecord,'CDPLACA');
    dtfeingreso                := zfx_library.fdtegetDate4XML(xmlRecord,  'FEINGRESO');
    vchcdcia_usuaria           := zfx_library.fvchgetString4XML(xmlRecord,'CDCIA_USUARIA');
    nmbnmtransito_documento    := zfx_library.fnmbgetNumber4XML(xmlRecord,'NMTRANSITO_DOCUMENTO');
    vchcdtipo_documento        := zfx_library.fvchgetString4XML(xmlRecord,'CDTIPO_DOCUMENTO');
    vchnmdoctransporte         := zfx_library.fvchgetString4XML(xmlRecord,'NMDOCTRANSPORTE');
    vchsngranel_nal            := zfx_library.fvchgetString4XML(xmlRecord,'SNGRANEL_NAL');
    vchsnparcial               := zfx_library.fvchGetString4XML(xmlRecord,'SNPARCIAL');
    vchnmformulario_zf         := zfx_library.fvchgetString4XML(xmlRecord,  'NMFORMULARIO_ZF');

    rcrRecordTrandoc.cdplaca               := vchcdplaca;
    rcrRecordTrandoc.feingreso             := dtfeingreso;
    rcrRecordTrandoc.cdcia_usuaria         := vchcdcia_usuaria;
    rcrRecordTrandoc.nmtransito_documento  := nmbnmtransito_documento;
    rcrRecordTrandoc.cdtipo_documento      := vchcdtipo_documento;
    rcrRecordTrandoc.nmdoctransporte       := vchnmdoctransporte;
    rcrRecordTrandoc.sngranel_nal          := vchsngranel_nal;

    open   cuTipos_ingreso (vchcdtipo_documento) ;
    fetch  cuTipos_ingreso into vchnacional;
    close  cuTipos_ingreso;


dbms_output.put_line('ENtra1');
    zfitzfw_documentos_x_cia.Update$(nmbErr, vchErrMsg, rcrRecord,cdusuario_ab);

    if vchnacional = 'S' then
       null;
       --ejecutar procedimiento en S que actualice granel nal y entrega parcial
dbms_output.put_line('ENtra2');       
       zfstzfw_documentos_x_cia.Actual_granel_y_o_parcial(nmbErr, vchErrMsg, rcrRecordTrandoc, vchsnparcial, vchnmformulario_zf, nmbActuaExi);
    end if;
dbms_output.put_line('ENtra3');
    if (nmbErr is not null) then
        Rollback;
        oclbXML := zfx_library.fclbsetMessage2XML(nmbErr, vchErrMsg);
        return;
    else
dbms_output.put_line('ENtra4');    
            zfstzfw_estados_planilla.UpdateEstadoPlanilla(rcrRecord.cdplaca,rcrRecord.cdcia_usuaria,rcrRecord.feingreso,rcrRecord.nmtransito_documento,
                                         rcrRecord.nmconsecutivo_doc,rcrRecord.cdusuario_reg,vnmplanilla,vcdestado,vdsplanilla,vchCsc,nmbErr,vchErrMsg);

        if (nmbErr is not null) then
            Rollback;
            oclbXML := zfx_library.fclbsetMessage2XML(nmbErr, vchErrMsg);
            return;
        end if;
    end if;
    commit;
    vchErrMsg := 'Operacion se completo con exito.';
    oclbXML := zfx_library.fclbsetMessage2XML(7, vchErrMsg);
    return;
end Update$;
------------------------------------------------------ Update$.prc ----------------------------------------------------
procedure Update$Transito(
    iclbRecord          in      clob,
    oclbXML             out     clob)
is
    rcrRecord           rtytzfw_documentos_x_cia;
    nmbErr              number;
    vchErrMsg           varchar2(256);
    cdusuario_ab        tzfw_documentos_x_cia.cdusuario_reg%type;
    vnmplanilla         tzfw_estados_planilla.nmplanilla%type;
    vcdestado           tzfw_estados_planilla.cdestado%type;
    vdsplanilla         tzfw_estados_planilla.dsplanilla%type;
    usuario   varchar2(20);
    xmlRecord           xmltype;
begin

    xmlRecord := xmltype(iclbRecord);

    rcrRecord.cdplaca                       := zfx_library.fvchgetString4XML(xmlRecord,'CDPLACA');
    rcrRecord.feingreso                     := zfx_library.fdtegetDate4XML(xmlRecord,  'FEINGRESO');
    rcrRecord.cdcia_usuaria                 := zfx_library.fvchgetString4XML(xmlRecord,'CDCIA_USUARIA');
    rcrRecord.nmtransito_documento          := zfx_library.fnmbgetNumber4XML(xmlRecord,'NMTRANSITO_DOCUMENTO');
    rcrRecord.nmconsecutivo_doc             := zfx_library.fnmbgetNumber4XML(xmlRecord,'NMCONSECUTIVO_DOC');
    rcrRecord.nmcontenedores                := zfx_library.fvchgetString4XML(xmlRecord,'NMCONTENEDORES');
    rcrRecord.snsol_desprecinte             := zfx_library.fvchgetString4XML(xmlRecord,'SNSOL_DESPRECINTE');
    rcrRecord.sndesprecinte                 := zfx_library.fvchgetString4XML(xmlRecord,'SNDESPRECINTE');
    rcrRecord.sninventario                  := zfx_library.fvchgetString4XML(xmlRecord,'SNINVENTARIO');
    rcrRecord.nmguia_bl_dex                 := zfx_library.fvchgetString4XML(xmlRecord,'NMGUIA_BL_DEX');
    rcrRecord.nmbultos_rel                  := zfx_library.fnmbgetNumber4XML(xmlRecord,'NMBULTOS_REL');
    rcrRecord.nmbultos_rec                  := zfx_library.fnmbgetNumber4XML(xmlRecord,'NMBULTOS_REC');
    rcrRecord.nmbultos_pla                  := zfx_library.fnmbgetNumber4XML(xmlRecord,'NMBULTOS_PLA');
    rcrRecord.nmpeso_rel                    := zfx_library.fnmbgetNumber4XML(xmlRecord,'NMPESO_REL');
    rcrRecord.nmpeso_rec                    := zfx_library.fnmbgetNumber4XML(xmlRecord,'NMPESO_REC');
    rcrRecord.nmpeso_pla                    := zfx_library.fnmbgetNumber4XML(xmlRecord,'NMPESO_PLA');
    rcrRecord.nmformulario_zf               := zfx_library.fvchgetString4XML(xmlRecord,'NMFORMULARIO_ZF');
    rcrRecord.cditem                        := zfx_library.fvchgetString4XML(xmlRecord,'CDITEM');
    rcrRecord.cdtransportadora              := zfx_library.fvchgetString4XML(xmlRecord,'CDTRANSPORTADORA');
    rcrRecord.cdtipo_mercancia              := zfx_library.fnmbgetNumber4XML(xmlRecord,'CDTIPO_MERCANCIA');
    rcrRecord.lsclase_mcia                  := zfx_library.fvchgetString4XML(xmlRecord,'LSCLASE_MCIA');
    rcrRecord.lsestado_mcia                 := zfx_library.fvchgetString4XML(xmlRecord,'LSESTADO_MCIA');
    rcrRecord.cdtipo_precinto               := zfx_library.fvchgetString4XML(xmlRecord,'CDTIPO_PRECINTO');
    rcrRecord.dsprecinto                    := zfx_library.fvchgetString4XML(xmlRecord,'DSPRECINTO');
    rcrRecord.dsobservacion                 := zfx_library.fvchgetString4XML(xmlRecord,'DSOBSERVACION');
    rcrRecord.fesol_desprecinte             := zfx_library.fdtegetDate4XML(xmlRecord,  'FESOL_DESPRECINTE');
    rcrRecord.cdusuario_soldesprecinte      := zfx_library.fvchgetString4XML(xmlRecord,'CDUSUARIO_SOLDESPRECINTE');
    rcrRecord.fedesprecinte                 := zfx_library.fdtegetDate4XML(xmlRecord,'FEDESPRECINTE');
    rcrRecord.cdusuario_desprecinte         := zfx_library.fvchgetString4XML(xmlRecord,'CDUSUARIO_DESPRECINTE');
    rcrRecord.feinventario                  := zfx_library.fdtegetDate4XML(xmlRecord,'FEINVENTARIO');
    rcrRecord.cdusuario_inventario          := zfx_library.fvchgetString4XML(xmlRecord,'CDUSUARIO_INVENTARIO');
    rcrRecord.sninconsistencia              := zfx_library.fvchgetString4XML(xmlRecord,'SNINCONSISTENCIA');
    rcrRecord.nmdocumento                   := zfx_library.fvchgetString4XML(xmlRecord,'NMDOCUMENTO');
    rcrRecord.dsmercancia                   := zfx_library.fvchgetString4XML(xmlRecord,'DSMERCANCIA');
    rcrRecord.nmtara_contenedor             := zfx_library.fnmbgetNumber4XML(xmlRecord,'NMTARA_CONTENEDOR');
    rcrRecord.cdusuario_reg                 := zfx_library.fvchgetString4XML(xmlRecord,'CDUSUARIO_REG');
    rcrRecord.id                            := zfx_library.fnmbgetNumber4XML(xmlRecord, 'ID');
    rcrRecord.cdusuario_aud                 := zfx_library.fvchGetString4XML(xmlRecord,  'CDUSUARIO_AUD');
    cdusuario_ab                            := zfx_library.fvchgetString4XML(xmlRecord,  'CDUSUARIO_AB');
    rcrRecord.snparcial                   := zfx_library.fvchGetString4XML(xmlRecord,  'SNPARCIAL');
    rcrRecord.dsinconsistencias           := zfx_library.fvchGetString4XML(xmlRecord,  'DSINCONSISTENCIAS');

    zfitzfw_documentos_x_cia.Update$(nmbErr, vchErrMsg, rcrRecord,cdusuario_ab);

    if (nmbErr is not null) then
        Rollback;
        oclbXML := zfx_library.fclbsetMessage2XML(nmbErr, vchErrMsg);
        return;
    end if;
    commit;
    vchErrMsg := 'Operacion se completo con exito.';
    oclbXML := zfx_library.fclbsetMessage2XML(7, vchErrMsg);
    return;
end Update$Transito;
------------------------------------------------------ UpdateUsuCalificadoCarga.prc ----------------------------------------------------
procedure UpdateUsuCalificadoCarga(
    iclbRecord          in      clob,
    oclbXML             out     clob)
is
    rcrRecord           rtytzfw_documentos_x_cia;
    nmbErr              number;
    vchErrMsg           varchar2(256);
    cdusuario_ab        tzfw_documentos_x_cia.cdusuario_reg%type;
    xmlRecord           xmltype;
begin

    xmlRecord := xmltype(iclbRecord);

    rcrRecord.cdplaca                       := zfx_library.fvchgetString4XML(xmlRecord,'CDPLACA');
    rcrRecord.feingreso                     := zfx_library.fdtegetDate4XML(xmlRecord,  'FEINGRESO');
    rcrRecord.cdcia_usuaria                 := zfx_library.fvchgetString4XML(xmlRecord,'CDCIA_USUARIA');
    rcrRecord.nmtransito_documento          := zfx_library.fnmbgetNumber4XML(xmlRecord,'NMTRANSITO_DOCUMENTO');
    rcrRecord.nmconsecutivo_doc             := zfx_library.fnmbgetNumber4XML(xmlRecord,'NMCONSECUTIVO_DOC');
    rcrRecord.nmcontenedores                := zfx_library.fvchgetString4XML(xmlRecord,'NMCONTENEDORES');
    rcrRecord.snsol_desprecinte             := zfx_library.fvchgetString4XML(xmlRecord,'SNSOL_DESPRECINTE');
    rcrRecord.sndesprecinte                 := zfx_library.fvchgetString4XML(xmlRecord,'SNDESPRECINTE');
    rcrRecord.sninventario                  := zfx_library.fvchgetString4XML(xmlRecord,'SNINVENTARIO');
    rcrRecord.nmguia_bl_dex                 := zfx_library.fvchgetString4XML(xmlRecord,'NMGUIA_BL_DEX');
    rcrRecord.nmbultos_rel                  := zfx_library.fnmbgetNumber4XML(xmlRecord,'NMBULTOS_REL');
    rcrRecord.nmbultos_rec                  := zfx_library.fnmbgetNumber4XML(xmlRecord,'NMBULTOS_REC');
    rcrRecord.nmbultos_pla                  := zfx_library.fnmbgetNumber4XML(xmlRecord,'NMBULTOS_PLA');
    rcrRecord.nmpeso_rel                    := zfx_library.fnmbgetNumber4XML(xmlRecord,'NMPESO_REL');
    rcrRecord.nmpeso_rec                    := zfx_library.fnmbgetNumber4XML(xmlRecord,'NMPESO_REC');
    rcrRecord.nmpeso_pla                    := zfx_library.fnmbgetNumber4XML(xmlRecord,'NMPESO_PLA');
    rcrRecord.nmformulario_zf               := zfx_library.fvchgetString4XML(xmlRecord,'NMFORMULARIO_ZF');
    --rcrRecord.cditem                        := zfx_library.fvchgetString4XML(xmlRecord,'CDITEM');
    rcrRecord.cdtransportadora              := zfx_library.fvchgetString4XML(xmlRecord,'CDTRANSPORTADORA');
    rcrRecord.cdtipo_mercancia              := zfx_library.fnmbgetNumber4XML(xmlRecord,'CDTIPO_MERCANCIA');
    rcrRecord.lsclase_mcia                  := zfx_library.fvchgetString4XML(xmlRecord,'LSCLASE_MCIA');
    rcrRecord.lsestado_mcia                 := zfx_library.fvchgetString4XML(xmlRecord,'LSESTADO_MCIA');
    rcrRecord.cdtipo_precinto               := zfx_library.fvchgetString4XML(xmlRecord,'CDTIPO_PRECINTO');
    rcrRecord.dsprecinto                    := zfx_library.fvchgetString4XML(xmlRecord,'DSPRECINTO');
    rcrRecord.dsobservacion                 := zfx_library.fvchgetString4XML(xmlRecord,'DSOBSERVACION');
    rcrRecord.fesol_desprecinte             := zfx_library.fdtegetDate4XML(xmlRecord,  'FESOL_DESPRECINTE');
    rcrRecord.cdusuario_soldesprecinte      := zfx_library.fvchgetString4XML(xmlRecord,'CDUSUARIO_SOLDESPRECINTE');
    rcrRecord.fedesprecinte                 := zfx_library.fdtegetDate4XML(xmlRecord,'FEDESPRECINTE');
    rcrRecord.cdusuario_desprecinte         := zfx_library.fvchgetString4XML(xmlRecord,'CDUSUARIO_DESPRECINTE');
    rcrRecord.feinventario                  := zfx_library.fdtegetDate4XML(xmlRecord,'FEINVENTARIO');
    rcrRecord.cdusuario_inventario          := zfx_library.fvchgetString4XML(xmlRecord,'CDUSUARIO_INVENTARIO');
    rcrRecord.sninconsistencia              := zfx_library.fvchgetString4XML(xmlRecord,'SNINCONSISTENCIA');
    rcrRecord.nmdocumento                   := zfx_library.fvchgetString4XML(xmlRecord,'NMDOCUMENTO');
    rcrRecord.dsmercancia                   := zfx_library.fvchgetString4XML(xmlRecord,'DSMERCANCIA');
    rcrRecord.nmtara_contenedor             := zfx_library.fnmbgetNumber4XML(xmlRecord,'NMTARA_CONTENEDOR');
    rcrRecord.cdusuario_reg                 := zfx_library.fvchgetString4XML(xmlRecord,'CDUSUARIO_REG');
    rcrRecord.id                            := zfx_library.fnmbgetNumber4XML(xmlRecord, 'ID');
    rcrRecord.cdusuario_aud                 := zfx_library.fvchgetString4XML(xmlRecord,'CDUSUARIO_AUD');
    cdusuario_ab                            := zfx_library.fvchgetString4XML(xmlRecord,  'CDUSUARIO_AB');

    zfitzfw_documentos_x_cia.UpdateUsuCalificadoCarga(nmbErr, vchErrMsg, rcrRecord,cdusuario_ab);

    if (nmbErr is not null) then
        Rollback;
        oclbXML := zfx_library.fclbsetMessage2XML(nmbErr, vchErrMsg);
        return;
    end if;

    commit;
    vchErrMsg := 'Operacion se completo con exito.';
    oclbXML := zfx_library.fclbsetMessage2XML(7, vchErrMsg);
    return;
end UpdateUsuCalificadoCarga;
--------------------------------------------UpdateUsuCalificado.prc ----------------------------------------------------
procedure UpdateUsuCalificado(
    iclbRecord          in      clob,
    oclbXML             out     clob)
is
    nmbErr               number;
    vchErrMsg            varchar2(256);
    cdplaca              varchar2(15);
    feingreso            date;
    cdcia_usuaria        tzfw_formularios.cdcia_usuaria%type;
    nmtransito_documento number(20);
    nmconsecutivo_doc    number(20);
    sninventario         varchar2(1);
    nmbultos_rec         number(5);
    nmpeso_rec           number(20,10);
    lsestado_mcia        varchar2(1);
    dsobservacion        varchar2(250);
    cdusuario_inventario varchar2(10);
    dsmercancia          varchar2(250);
    cdusuario_ab         tzfw_documentos_x_cia.cdusuario_reg%type;
    xmlRecord            xmltype;
begin

    xmlRecord := xmltype(iclbRecord);

    cdplaca                       := zfx_library.fvchgetString4XML(xmlRecord,'CDPLACA');
    feingreso                     := zfx_library.fdtegetDate4XML(xmlRecord,  'FEINGRESO');
    cdcia_usuaria                 := zfx_library.fvchgetString4XML(xmlRecord,'CDCIA_USUARIA');
    nmtransito_documento          := zfx_library.fnmbgetNumber4XML(xmlRecord,'NMTRANSITO_DOCUMENTO');
    nmconsecutivo_doc             := zfx_library.fnmbgetNumber4XML(xmlRecord,'NMCONSECUTIVO_DOC');
    sninventario                  := zfx_library.fvchgetString4XML(xmlRecord,'SNINVENTARIO');
    nmbultos_rec                  := zfx_library.fnmbgetNumber4XML(xmlRecord,'NMBULTOS_REC ');
    nmpeso_rec                    := zfx_library.fnmbgetNumber4XML(xmlRecord,'NMPESO_REC');
    lsestado_mcia                 := zfx_library.fvchgetString4XML(xmlRecord,'LSESTADO_MCIA');
    dsobservacion                 := zfx_library.fvchgetString4XML(xmlRecord,'DSOBSERVACION');
    cdusuario_inventario          := zfx_library.fvchgetString4XML(xmlRecord,'CDUSUARIO_INVENTARIO');
    dsmercancia                   := zfx_library.fvchgetString4XML(xmlRecord,'DSMERCANCIA');
    cdusuario_ab                  := zfx_library.fvchgetString4XML(xmlRecord,  'CDUSUARIO_AB');

    -- mirsan 20210906 CC 89, si el parametro ACTA_TRANSITO_NOREQUERIDOS=S y se envia el estado de la mercancia en null debe ponerla B(Buena)
    -- inicio
    zfstzfw_parametros.Query$DsParametro('ACTA_TRANSITO_NOREQUERIDOS');    
    if zfstzfw_parametros.SQL$$Found  then        
        if nvl(zfstzfw_parametros.DsValor$$,'N') ='S' then 
            if lsestado_mcia is null or lsestado_mcia ='' then lsestado_mcia:='B'; end if;
        end if;
    end if;
    --fin
    
    zfitzfw_documentos_x_cia.UpdateUsuCalificado(nmbErr,vchErrMsg,cdplaca,feingreso,cdcia_usuaria,nmtransito_documento,
                                                 nmconsecutivo_doc,sninventario,nmbultos_rec,nmpeso_rec,lsestado_mcia,
                                                 dsobservacion,cdusuario_inventario,dsmercancia,cdusuario_ab);

    if (nmbErr is not null) then
        Rollback;
        oclbXML := zfx_library.fclbsetMessage2XML(nmbErr, vchErrMsg);
        return;
    end if;

    commit;

    vchErrMsg := 'Operacion se completo con exito.';
    oclbXML := zfx_library.fclbsetMessage2XML(7, vchErrMsg);
    return;
end UpdateUsuCalificado;
--------------------------------------------UpdateUsuClfcdoDsprcinte.prc ----------------------------------------------------
procedure UpdateUsuClfcdoDsprcinte(
    iclbRecord          in      clob,
    oclbXML             out     clob)
is
    nmbErr                number;
    vchErrMsg             varchar2(256);
    cdplaca               varchar2(15);
    feingreso             date;
    cdcia_usuaria         tzfw_formularios.cdcia_usuaria%type;
    nmtransito_documento  number(20);
    nmconsecutivo_doc     number(20);
    sndesprecinte         varchar2(1);
    lsclase_mcia          varchar2(1);
    cdtipo_precinto       varchar2(5);
    dsprecinto            varchar2(100);
    dsobservacion         varchar2(250);
    cdusuario_desprecinte varchar2(10);
    cdusuario_ab          tzfw_documentos_x_cia.cdusuario_reg%type;
    xmlRecord            xmltype;
begin

    xmlRecord := xmltype(iclbRecord);

    cdplaca                       := zfx_library.fvchgetString4XML(xmlRecord,'CDPLACA');
    feingreso                     := zfx_library.fdtegetDate4XML(xmlRecord,  'FEINGRESO');
    cdcia_usuaria                 := zfx_library.fvchgetString4XML(xmlRecord,'CDCIA_USUARIA');
    nmtransito_documento          := zfx_library.fnmbgetNumber4XML(xmlRecord,'NMTRANSITO_DOCUMENTO');
    nmconsecutivo_doc             := zfx_library.fnmbgetNumber4XML(xmlRecord,'NMCONSECUTIVO_DOC');
    sndesprecinte                 := zfx_library.fvchgetString4XML(xmlRecord,'SNDESPRECINTE');
    lsclase_mcia                  := zfx_library.fvchgetString4XML(xmlRecord,'LSCLASE_MCIA');
    cdtipo_precinto               := zfx_library.fvchgetString4XML(xmlRecord,'CDTIPO_PRECINTO');
    dsprecinto                    := zfx_library.fvchgetString4XML(xmlRecord,'DSPRECINTO');
    dsobservacion                 := zfx_library.fvchgetString4XML(xmlRecord,'DSOBSERVACION');
    cdusuario_desprecinte         := zfx_library.fvchgetString4XML(xmlRecord,'CDUSUARIO_DESPRECINTE');
    cdusuario_ab                  := zfx_library.fvchgetString4XML(xmlRecord,  'CDUSUARIO_AB');

    zfitzfw_documentos_x_cia.UpdateUsuClfcdoDsprcinte(nmbErr,vchErrMsg,cdplaca,feingreso,cdcia_usuaria,nmtransito_documento,
                                                      nmconsecutivo_doc,sndesprecinte,lsclase_mcia,cdtipo_precinto,dsprecinto,
                                                      dsobservacion,cdusuario_desprecinte,cdusuario_ab);

    if (nmbErr is not null) then
        Rollback;
        oclbXML := zfx_library.fclbsetMessage2XML(nmbErr, vchErrMsg);
        return;
    end if;
    commit;
    vchErrMsg := 'Operacion se completo con exito.';
    oclbXML := zfx_library.fclbsetMessage2XML(7, vchErrMsg);
    return;
end UpdateUsuClfcdoDsprcinte;
--------------------------------------------UpdVerificarTransito.prc ----------------------------------------------------
procedure UpdVerificarTransito(
    iclbRecord          in      clob,
    oclbXML             out     clob)
is
    nmbErr                number;
    vchErrMsg             varchar2(256);
    cdplaca               varchar2(15);
    feingreso             date;
    cdcia_usuaria         tzfw_formularios.cdcia_usuaria%type;
    nmtransito_documento  number(20);
    nmconsecutivo_doc     number(20);
    snsol_desprecinte     varchar2(1);
    sndesprecinte         varchar2(1);
    sninventario          varchar2(1);
    nmbultos_rel          number(5);
    nmbultos_rec          number(5);
    nmpeso_rel            number(20,10);
    nmpeso_rec            number(20,10);
    nmformulario_zf       tzfw_formularios.nmformulario_zf%type;
    cdtipo_precinto       varchar2(5);
    nmdocumento           varchar2(35);
    cdusuario_ab          tzfw_documentos_x_cia.cdusuario_reg%type;
    xmlRecord            xmltype;
begin

    xmlRecord := xmltype(iclbRecord);

    cdplaca                       := zfx_library.fvchgetString4XML(xmlRecord,'CDPLACA');
    feingreso                     := zfx_library.fdtegetDate4XML(xmlRecord,  'FEINGRESO');
    cdcia_usuaria                 := zfx_library.fvchgetString4XML(xmlRecord,'CDCIA_USUARIA');
    nmtransito_documento          := zfx_library.fnmbgetNumber4XML(xmlRecord,'NMTRANSITO_DOCUMENTO');
    nmconsecutivo_doc             := zfx_library.fnmbgetNumber4XML(xmlRecord,'NMCONSECUTIVO_DOC');
    snsol_desprecinte             := zfx_library.fvchgetString4XML(xmlRecord,'SNSOL_DESPRECINTE');
    sndesprecinte                 := zfx_library.fvchgetString4XML(xmlRecord,'SNDESPRECINTE');
    sninventario                  := zfx_library.fvchgetString4XML(xmlRecord,'SNINVENTARIO');
    nmbultos_rel                  := zfx_library.fnmbgetNumber4XML(xmlRecord,'NMBULTOS_REL');
    nmbultos_rec                  := zfx_library.fnmbgetNumber4XML(xmlRecord,'NMBULTOS_REC');
    nmpeso_rel                    := zfx_library.fnmbgetNumber4XML(xmlRecord,'NMPESO_REL');
    nmpeso_rec                    := zfx_library.fnmbgetNumber4XML(xmlRecord,'NMPESO_REC');
    nmformulario_zf               := zfx_library.fvchgetString4XML(xmlRecord,'NMFORMULARIO_ZF');
    cdtipo_precinto               := zfx_library.fvchgetString4XML(xmlRecord,'CDTIPO_PRECINTO');
    nmdocumento                   := zfx_library.fvchgetString4XML(xmlRecord,'NMDOCUMENTO');
    cdusuario_ab                  := zfx_library.fvchgetString4XML(xmlRecord,  'CDUSUARIO_AB');

    zfitzfw_documentos_x_cia.UpdVerificarTransito(nmbErr,vchErrMsg,cdplaca,feingreso,cdcia_usuaria,nmtransito_documento,
                                                  nmconsecutivo_doc,snsol_desprecinte,sndesprecinte,sninventario,
                                                  nmbultos_rel,nmbultos_rec,nmpeso_rel,nmpeso_rec,nmformulario_zf,
                                                  cdtipo_precinto,nmdocumento,cdusuario_ab);

    if (nmbErr is not null) then
        Rollback;
        oclbXML := zfx_library.fclbsetMessage2XML(nmbErr, vchErrMsg);
        return;
    end if;
    commit;
    vchErrMsg := 'Operacion se completo con exito.';
    oclbXML := zfx_library.fclbsetMessage2XML(7, vchErrMsg);
    return;
end UpdVerificarTransito;
------------------------------------------------------ Delete$.prc ----------------------------------------------------
procedure Delete$(
    iclbRecord          in      clob,
    oclbXML             out     clob)
is
    rcrRecord           rtytzfw_documentos_x_cia;
    nmbErr              number;
    vchErrMsg           varchar2(256);
    xmlRecord           xmltype;
begin

    xmlRecord := xmltype(iclbRecord);

    rcrRecord.id                       := zfx_library.fnmbgetNumber4XML(xmlRecord,  'ID');
    rcrRecord.cdusuario_aud            := zfx_library.fvchgetString4XML(xmlRecord,'CDUSUARIO_AUD');

    zfitzfw_documentos_x_cia.Delete$(nmbErr, vchErrMsg, rcrRecord);

    if (nmbErr is not null) then
        Rollback;
        oclbXML := zfx_library.fclbsetMessage2XML(nmbErr, vchErrMsg);
        return;
    end if;

    commit;
    vchErrMsg := 'Operacion se completo con exito.';
    oclbXML := zfx_library.fclbsetMessage2XML(7, vchErrMsg);
    return;
end Delete$;
--------------------------------------- XQuery$.prc -------------------------------------------------------------------
procedure XQuery(
    iclbParam           in clob,
    oclbXML             out clob)
is
    nmbErr              number;
    vchErrMsg           varchar2(256);
    clbXMLResult        clob;
begin

    zfitzfw_documentos_x_cia.XQuery(nmbErr, vchErrMsg,clbXMLResult);

    if (nmbErr is not null) then
        oclbXML := zfx_library.fclbsetMessage2XML(nmbErr,vchErrMsg);
        return;
    end if;
    if (clbXMLResult is not null) then
        oclbXML := clbXMLResult;
    else
        vchErrMsg := 'No se encontraron registros';
        oclbXML := zfx_library.fclbsetMessage2XML(6,vchErrMsg);
    end if;
    return;
end XQuery;

--------------------------------------- XMntreoTrnsto.prc -------------------------------------------------------------------
procedure XMntreoTrnsto(
    iclbParam           in clob,
    oclbXML             out clob)
is
    nmbErr              number;
    vchErrMsg           varchar2(256);
    vchFilter           varchar2(1024);
    clbXMLResult        clob;
    xmlRecord           xmltype;
begin
    xmlRecord := xmltype(iclbParam);

    vchFilter           := zfx_library.fvchgetString4XML(xmlRecord,  'FILTER');

    zfitzfw_documentos_x_cia.XMntreoTrnsto(nmbErr, vchErrMsg, vchFilter, clbXMLResult);

    if (nmbErr is not null) then
        oclbXML := zfx_library.fclbsetMessage2XML(nmbErr,vchErrMsg);
        return;
    end if;
    if (clbXMLResult is not null) then
        oclbXML := clbXMLResult;
    else
        vchErrMsg := 'No se encontraron registros';
        oclbXML := zfx_library.fclbsetMessage2XML(6,vchErrMsg);
    end if;
    return;
end XMntreoTrnsto;
--------------------------------------- XActasTransito.prc -------------------------------------------------------------------
procedure XActasTransito(
    iclbParam           in clob,
    oclbXML             out clob)
is
    nmbErr              number;
    vchErrMsg           varchar2(256);
    vchFilter           varchar2(1024);
    cdcia_usuaria       tzfw_documentos_x_cia.cdcia_usuaria%type;
    nmTransito          tzfw_actas_transitos.nmtransito%type;
    clbXMLResult        clob;
    xmlRecord           xmltype;
begin
    xmlRecord := xmltype(iclbParam);

    vchFilter               := zfx_library.fvchgetString4XML(xmlRecord,'FILTER');
    cdcia_usuaria           := zfx_library.fvchgetString4XML(xmlRecord,'CIA_ACTA');
    nmTransito              := zfx_library.fvchgetString4XML(xmlRecord,'NMTRANSITO');

    zfitzfw_documentos_x_cia.XActasTransito(nmbErr,vchErrMsg,vchFilter,cdcia_usuaria,nmTransito,clbXMLResult);

    if (nmbErr is not null) then
        oclbXML := zfx_library.fclbsetMessage2XML(nmbErr,vchErrMsg);
        return;
    end if;
    if (clbXMLResult is not null) then
        oclbXML := clbXMLResult;
    else
        vchErrMsg := 'No se encontraron registros';
        oclbXML := zfx_library.fclbsetMessage2XML(6,vchErrMsg);
    end if;
    return;
end XActasTransito;
--------------------------------------- XCnsltaMovCamiones.prc -------------------------------------------------------------------
procedure XCnsltaMovCamiones(
    iclbParam           in clob,
    oclbXML             out clob)
is
    nmbErr              number;
    vchErrMsg           varchar2(256);
    vchFilter           varchar2(1024);
    clbXMLResult        clob;
    xmlRecord           xmltype;
begin
    xmlRecord := xmltype(iclbParam);

    vchFilter               := zfx_library.fvchgetString4XML(xmlRecord,'FILTER');

    zfitzfw_documentos_x_cia.XCnsltaMovCamiones(nmbErr,vchErrMsg,vchFilter,clbXMLResult);

    if (nmbErr is not null) then
        oclbXML := zfx_library.fclbsetMessage2XML(nmbErr,vchErrMsg);
        return;
    end if;
    if (clbXMLResult is not null) then
        oclbXML := clbXMLResult;
    else
        vchErrMsg := 'No se encontraron registros';
        oclbXML := zfx_library.fclbsetMessage2XML(6,vchErrMsg);
    end if;
    return;
end XCnsltaMovCamiones;
--------------------------------------- XPesosxCamion.prc -------------------------------------------------------------------
procedure XPesosxCamion(
    iclbParam           in clob,
    oclbXML             out clob)
is
    nmbErr              number;
    vchErrMsg           varchar2(256);
    vchcdPlaca          tzfw_documentos_x_cia.cdplaca%type;
    clbXMLResult        clob;
    xmlRecord           xmltype;
begin
    xmlRecord := xmltype(iclbParam);

    vchcdPlaca               := zfx_library.fvchgetString4XML(xmlRecord,'CDPLACA');

    zfitzfw_documentos_x_cia.XPesosxCamion(nmbErr,vchErrMsg,vchcdPlaca,clbXMLResult);

    if (nmbErr is not null) then
        oclbXML := zfx_library.fclbsetMessage2XML(nmbErr,vchErrMsg);
        return;
    end if;
    if (clbXMLResult is not null) then
        oclbXML := clbXMLResult;
    else
        vchErrMsg := 'No se encontraron registros';
        oclbXML := zfx_library.fclbsetMessage2XML(6,vchErrMsg);
    end if;
    return;
end XPesosxCamion;
--------------------------------------- XUsuClficadoCnslta.prc -------------------------------------------------------------------
procedure XUsuClficadoCnslta(
    iclbParam           in clob,
    oclbXML             out clob)
is
    nmbErr              number;
    vchErrMsg           varchar2(256);
    vchFilter           varchar2(1024);
    clbXMLResult        clob;
    xmlRecord           xmltype;
begin
    xmlRecord := xmltype(iclbParam);

    vchFilter               := zfx_library.fvchgetString4XML(xmlRecord,'FILTER');

    zfitzfw_documentos_x_cia.XUsuClficadoCnslta(nmbErr,vchErrMsg,vchFilter,clbXMLResult);

    if (nmbErr is not null) then
        oclbXML := zfx_library.fclbsetMessage2XML(nmbErr,vchErrMsg);
        return;
    end if;
    if (clbXMLResult is not null) then
        oclbXML := clbXMLResult;
    else
        vchErrMsg := 'No se encontraron registros';
        oclbXML := zfx_library.fclbsetMessage2XML(6,vchErrMsg);
    end if;
    return;
end XUsuClficadoCnslta;
--------------------------------------- XUsuClficadoCarga.prc -------------------------------------------------------------------
procedure XUsuClficadoCarga(
    iclbParam           in clob,
    oclbXML             out clob)
is
    nmbErr              number;
    vchErrMsg           varchar2(256);
    vchFilter           varchar2(1024);
    clbXMLResult        clob;
    xmlRecord           xmltype;
begin
    xmlRecord := xmltype(iclbParam);

    vchFilter               := zfx_library.fvchgetString4XML(xmlRecord,'FILTER');

    zfitzfw_documentos_x_cia.XUsuClficadoCarga(nmbErr,vchErrMsg,vchFilter,clbXMLResult);

    if (nmbErr is not null) then
        oclbXML := zfx_library.fclbsetMessage2XML(nmbErr,vchErrMsg);
        return;
    end if;
    if (clbXMLResult is not null) then
        oclbXML := clbXMLResult;
    else
        vchErrMsg := 'No se encontraron registros';
        oclbXML := zfx_library.fclbsetMessage2XML(6,vchErrMsg);
    end if;
    return;
end XUsuClficadoCarga;
--------------------------------------- XUsuClficadoCarga.prc -------------------------------------------------------------------
procedure XQuery$Formulario(
    iclbParam           in clob,
    oclbXML             out clob)
is
    nmbErr              number;
    vchErrMsg           varchar2(256);
    vchFilter           varchar2(1024);
    vchCiaUsuaria       tzfw_formularios.cdcia_usuaria%type;
    vchFormulario       tzfw_formularios.nmformulario_zf%type;
    clbXMLResult        clob;
    xmlRecord           xmltype;
begin
    xmlRecord := xmltype(iclbParam);

    vchCiaUsuaria           := zfx_library.fvchgetString4XML(xmlRecord,'CDCIA_USUARIA');
    vchFormulario           := zfx_library.fvchgetString4XML(xmlRecord,'NMFORMULARIO_ZF');

    zfstzfw_documentos_x_cia.XQuery$Formulario(vchCiaUsuaria,vchFormulario,clbXMLResult);

    if (nmbErr is not null) then
        oclbXML := zfx_library.fclbsetMessage2XML(nmbErr,vchErrMsg);
        return;
    end if;
    if (clbXMLResult is not null) then
        oclbXML := clbXMLResult;
    else
        vchErrMsg := 'No se encontraron registros';
        oclbXML := zfx_library.fclbsetMessage2XML(6,vchErrMsg);
    end if;
    return;
end XQuery$Formulario;
--------------------------------------- XUsuClficadoInvntrio.prc -------------------------------------------------------------------
procedure XUsuClficadoInvntrio(
    iclbParam           in clob,
    oclbXML             out clob)
is
    nmbErr              number;
    vchErrMsg           varchar2(256);
    vchFilter           varchar2(1024);
    clbXMLResult        clob;
    xmlRecord           xmltype;
begin
    xmlRecord := xmltype(iclbParam);

    vchFilter               := zfx_library.fvchgetString4XML(xmlRecord,'FILTER');

    zfitzfw_documentos_x_cia.XUsuClficadoInvntrio(nmbErr,vchErrMsg,vchFilter,clbXMLResult);

    if (nmbErr is not null) then
        oclbXML := zfx_library.fclbsetMessage2XML(nmbErr,vchErrMsg);
        return;
    end if;
    if (clbXMLResult is not null) then
        oclbXML := clbXMLResult;
    else
        vchErrMsg := 'No se encontraron registros';
        oclbXML := zfx_library.fclbsetMessage2XML(6,vchErrMsg);
    end if;
    return;
end XUsuClficadoInvntrio;
--------------------------------------- XUsuClficadoDsprcinte.prc -------------------------------------------------------------------
procedure XUsuClficadoDsprcinte(
    iclbParam           in clob,
    oclbXML             out clob)
is
    nmbErr              number;
    vchErrMsg           varchar2(256);
    vchFilter           varchar2(1024);
    clbXMLResult        clob;
    xmlRecord           xmltype;
begin
    xmlRecord := xmltype(iclbParam);

    vchFilter               := zfx_library.fvchgetString4XML(xmlRecord,'FILTER');

    zfitzfw_documentos_x_cia.XUsuClficadoDsprcinte(nmbErr,vchErrMsg,vchFilter,clbXMLResult);

    if (nmbErr is not null) then
        oclbXML := zfx_library.fclbsetMessage2XML(nmbErr,vchErrMsg);
        return;
    end if;
    if (clbXMLResult is not null) then
        oclbXML := clbXMLResult;
    else
        vchErrMsg := 'No se encontraron registros';
        oclbXML := zfx_library.fclbsetMessage2XML(6,vchErrMsg);
    end if;
    return;
end XUsuClficadoDsprcinte;
--------------------------------------- XUsuClficadoRegDoc.prc -------------------------------------------------------------------
procedure XUsuClficadoRegDoc(
    iclbParam           in clob,
    oclbXML             out clob)
is
    nmbErr              number;
    vchErrMsg           varchar2(256);
    vchFilter           varchar2(1024);
    clbXMLResult        clob;
    xmlRecord           xmltype;
begin
    xmlRecord := xmltype(iclbParam);

    vchFilter               := zfx_library.fvchgetString4XML(xmlRecord,'FILTER');

    zfitzfw_documentos_x_cia.XUsuClficadoRegDoc(nmbErr,vchErrMsg,vchFilter,clbXMLResult);

    if (nmbErr is not null) then
        oclbXML := zfx_library.fclbsetMessage2XML(nmbErr,vchErrMsg);
        return;
    end if;
    if (clbXMLResult is not null) then
        oclbXML := clbXMLResult;
    else
        vchErrMsg := 'No se encontraron registros';
        oclbXML := zfx_library.fclbsetMessage2XML(6,vchErrMsg);
    end if;
    return;
end XUsuClficadoRegDoc;
--------------------------------------- XVerificarTransito.prc -------------------------------------------------------------------
procedure XVerificarTransito(
    iclbParam           in clob,
    oclbXML             out clob)
is
    nmbErr              number;
    vchErrMsg           varchar2(256);
    vchFilter           varchar2(1024);
    clbXMLResult        clob;
    xmlRecord           xmltype;
begin
    xmlRecord := xmltype(iclbParam);

    vchFilter               := zfx_library.fvchgetString4XML(xmlRecord,'FILTER');

    zfitzfw_documentos_x_cia.XVerificarTransito(nmbErr,vchErrMsg,vchFilter,clbXMLResult);

    if (nmbErr is not null) then
        oclbXML := zfx_library.fclbsetMessage2XML(nmbErr,vchErrMsg);
        return;
    end if;
    if (clbXMLResult is not null) then
        oclbXML := clbXMLResult;
    else
        vchErrMsg := 'No se encontraron registros';
        oclbXML := zfx_library.fclbsetMessage2XML(6,vchErrMsg);
    end if;
    return;
end XVerificarTransito;
----------------------------------------------------------CamposFijosUsuCalRegDoc.prc---------------------------------
procedure CamposFijosUsuCalRegDoc(
    oclbXML                         out     clob)
is
    temp                            varchar2(512);
begin
    temp := temp||'<?xml version="1.0"?>'||chr(10);
    temp := temp||'<ROWSET>' || chr(10);
    temp := temp|| '<ROW>' || chr(10);
    temp := temp||'<CDCAMPO_TABLA>'||'NMBULTOS_REL'||'</CDCAMPO_TABLA>'||chr(10);
    temp := temp||'</ROW>'|| chr(10);
    temp := temp|| '<ROW>' || chr(10);
    temp := temp||'<CDCAMPO_TABLA>'||'NMPESO_REL'||'</CDCAMPO_TABLA>'||chr(10);
    temp := temp||'</ROW>'|| chr(10);
    temp := temp|| '<ROW>' || chr(10);
    temp := temp||'<CDCAMPO_TABLA>'||'NMFORMULARIO_ZF'||'</CDCAMPO_TABLA>'||chr(10);
    temp := temp||'</ROW>'|| chr(10);
    temp := temp|| '<ROW>' || chr(10);
    temp := temp||'<CDCAMPO_TABLA>'||'CDTRANSPORTADORA'||'</CDCAMPO_TABLA>'||chr(10);
    temp := temp||'</ROW>'|| chr(10);
    temp := temp|| '<ROW>' || chr(10);
    temp := temp||'<CDCAMPO_TABLA>'||'DSOBSERVACION'||'</CDCAMPO_TABLA>'||chr(10);
    temp := temp||'</ROW>'|| chr(10);
    temp := temp||'</ROWSET>'|| chr(10);
    oclbXML := temp;
    return;
end CamposFijosUsuCalRegDoc;
----------------------------------------------------------CamposFijosUsuCalRegDoc2.prc---------------------------------
procedure CamposFijosUsuCalRegDoc2(
    oclbXML                         out     clob)
is
    temp                            varchar2(512);
begin
    temp := temp||'<?xml version="1.0"?>'||chr(10);
    temp := temp||'<ROWSET>' || chr(10);
    temp := temp|| '<ROW>' || chr(10);
    temp := temp||'<CDCAMPO_TABLA>'||'NMCONTENEDORES'||'</CDCAMPO_TABLA>'||chr(10);
    temp := temp||'</ROW>'|| chr(10);
    temp := temp|| '<ROW>' || chr(10);
    temp := temp||'<CDCAMPO_TABLA>'||'NMGUIA_BL_DEX'||'</CDCAMPO_TABLA>'||chr(10);
    temp := temp||'</ROW>'|| chr(10);
    temp := temp|| '<ROW>' || chr(10);
    temp := temp||'<CDCAMPO_TABLA>'||'NMBULTOS_REL'||'</CDCAMPO_TABLA>'||chr(10);
    temp := temp||'</ROW>'|| chr(10);
    temp := temp|| '<ROW>' || chr(10);
    temp := temp||'<CDCAMPO_TABLA>'||'NMPESO_REL'||'</CDCAMPO_TABLA>'||chr(10);
    temp := temp||'</ROW>'|| chr(10);
    temp := temp|| '<ROW>' || chr(10);
    temp := temp||'<CDCAMPO_TABLA>'||'NMFORMULARIO_ZF'||'</CDCAMPO_TABLA>'||chr(10);
    temp := temp||'</ROW>'|| chr(10);
    temp := temp||'</ROWSET>'|| chr(10);
    oclbXML := temp;
    return;
end CamposFijosUsuCalRegDoc2;
----------------------------------------------------------CamposDnmicosUsuCalRegDoc.prc---------------------------------
procedure CamposDnmicosUsuCalRegDoc(
    icdtipo_documento               in      varchar2,
    oclbXML                         out     clob)
is
    nmbErr                          number;
    vchErrMsg                       varchar2(256);
    clbXMLResult                    clob;

begin

    zfitzfw_documentos_x_cia.CamposDnmicosUsuCalRegDoc(nmbErr,vchErrMsg,icdtipo_documento,clbXMLResult);

    if (nmbErr is not null) then
        oclbXML := zfx_library.fclbsetMessage2XML(nmbErr,vchErrMsg);
        return;
    end if;
    if (clbXMLResult is not null) then
        oclbXML := clbXMLResult;
    else
        vchErrMsg := 'No se encontraron registros';
        oclbXML := zfx_library.fclbsetMessage2XML(6,vchErrMsg);
    end if;
    return;
end CamposDnmicosUsuCalRegDoc;
----------------------------------------------------------CamposUsuClficadoRegDoc.prc---------------------------------
procedure CamposUsuClficadoRegDoc(
    iclbRecord                      in      clob,
    oclbXML                         out     clob)
is
    cdtipo_documento                varchar2(3);
    cdcia_usuaria                   tzfw_usuarios.cdcia_usuaria%type;
    cia_operadora                   tzfw_usuarios.cdcia_usuaria%type;
    transito                        varchar2(100);
    clbXML                          clob;
    xmlRecord                       xmltype;
begin

    xmlRecord := xmltype(iclbRecord);

    cdtipo_documento               := zfx_library.fvchgetString4XML(xmlRecord,'CDTIPO_DOCUMENTO');
    cdcia_usuaria                  := zfx_library.fvchgetString4XML(xmlRecord,'CDCIA_USUARIA');
    cia_operadora                  := zfx_library.fvchgetString4XML(xmlRecord,'CIA_OPERADORA');
    transito                       := zfx_library.fvchgetString4XML(xmlRecord,'TRANSITO');

    /*if (cdtipo_documento is null and cdcia_usuaria <> cia_operadora) then
        zfxtzfw_documentos_x_cia.CamposFijosUsuCalRegDoc(clbXML);
        oclbXML :=clbXML;
        return;
    end if;*/

    if (cdtipo_documento is not null and cdcia_usuaria <> cia_operadora) then
        zfxtzfw_documentos_x_cia.CamposDnmicosUsuCalRegDoc(cdtipo_documento,clbXML);
        oclbXML :=clbXML;
        return;
    end if;

    /*if (instr(transito,cdtipo_documento) > 0 and cdcia_usuaria <> cia_operadora) then
        zfxtzfw_documentos_x_cia.CamposFijosUsuCalRegDoc2(clbXML);
        oclbXML :=clbXML;
        return;
    end if;*/

    return;
end CamposUsuClficadoRegDoc;
------------------------------------------------------ ValidarUsuClficadoRegDoc.prc ----------------------------------------------------
procedure ValidarUsuClficadoRegDoc(
    iclbRecord          in      clob,
    oclbXML             out     clob)
is
    nmbErr                  number;
    vchErrMsg               varchar2(512);
    cdplaca                 varchar2(15);
    feingreso               date;
    cdcia_usuaria           tzfw_usuarios.cdcia_usuaria%type;
    nmtransito_documento    number(20);
    cdtipo_documento        varchar2(3);
    cia_usuaria             tzfw_usuarios.cdcia_usuaria%type;
    cia_operadora           tzfw_usuarios.cdcia_usuaria%type;
    transito                varchar2(100);
    guia                    varchar2(100);
    porcentaje_peso         number;
    cdidentificacion        varchar2(10);
    nmdoctransporte         varchar2(25);
    nmtotal_doctransporte   number(5);
    xmlRecord          xmltype;
begin

    xmlRecord := xmltype(iclbRecord);

    cdplaca                                 := zfx_library.fvchgetString4XML(xmlRecord,'CDPLACA');
    feingreso                               := zfx_library.fdtegetDate4XML(xmlRecord,  'FEINGRESO');
    cdcia_usuaria                           := zfx_library.fvchgetString4XML(xmlRecord,'CDCIA_USUARIA');
    nmtransito_documento                    := zfx_library.fnmbgetNumber4XML(xmlRecord,'NMTRANSITO_DOCUMENTO');
    cdtipo_documento                        := zfx_library.fvchgetString4XML(xmlRecord,'CDTIPO_DOCUMENTO');
    cia_usuaria                             := zfx_library.fvchgetString4XML(xmlRecord,'CIA_USUARIA');
    cia_operadora                           := zfx_library.fvchgetString4XML(xmlRecord,'CIA_OPERADORA');
    cdidentificacion                        := zfx_library.fvchgetString4XML(xmlRecord,'CDIDENTIFICACION');
    transito                                := zfx_library.fvchgetString4XML(xmlRecord,'TRANSITO');
    guia                                    := zfx_library.fvchgetString4XML(xmlRecord,'GUIA');
    porcentaje_peso                         := zfx_library.fnmbgetNumber4XML(xmlRecord,'PORCENTAJE_PESO');
    nmdoctransporte                         := zfx_library.fvchgetString4XML(xmlRecord,'NMDOCTRANSPORTE');
    nmtotal_doctransporte                   := zfx_library.fnmbgetNumber4XML(xmlRecord,'NMTOTAL_DOCTRANSPORTE');

    if (instr(transito,cdtipo_documento) = 0 and cdcia_usuaria <> cia_operadora) then
           zfitzfw_documentos_x_cia.EvaluarGuia(nmbErr,vchErrMsg,cdplaca,feingreso,cdcia_usuaria,nmtransito_documento,
                                                cdtipo_documento,nmdoctransporte,nmtotal_doctransporte,cdidentificacion,guia,porcentaje_peso);

           if (nmbErr is not null) then
                Rollback;
                oclbXML := zfx_library.fclbsetMessage2XML(nmbErr, vchErrMsg);
                return;
          end if;
          commit;
          vchErrMsg := 'Operacion se completo con exito.';
          oclbXML := zfx_library.fclbsetMessage2XML(7, vchErrMsg);
          return;
    end if;

    if (instr(transito,cdtipo_documento) > 0 and cdcia_usuaria <> cia_operadora) then

          zfitzfw_documentos_x_cia.ValidarNumRegUsuClfcado(nmbErr,vchErrMsg,cdplaca,feingreso,cdcia_usuaria,nmtransito_documento,transito,cdidentificacion);

          if (nmbErr is not null) then
                Rollback;
                oclbXML := zfx_library.fclbsetMessage2XML(nmbErr, vchErrMsg);
                return;
          end if;

          zfitzfw_documentos_x_cia.ActualizarFrm(nmbErr,vchErrMsg,cdplaca,feingreso,cdcia_usuaria,nmtransito_documento,
                                                 cdtipo_documento,transito,cdidentificacion);
          if (nmbErr is not null) then
                Rollback;
                oclbXML := zfx_library.fclbsetMessage2XML(nmbErr, vchErrMsg);
                return;
          end if;
          commit;
          vchErrMsg := 'Operacion se completo con exito.';
          oclbXML := zfx_library.fclbsetMessage2XML(7, vchErrMsg);
          return;
    end if;

    return;
end ValidarUsuClficadoRegDoc;
------------------------------------------------------ ValidarUsuClficadoRegDoc.prc ----------------------------------------------------
procedure ValidarUsuClficadoRegGuia(
    iclbRecord          in      clob,
    oclbXML             out     clob)
is
    nmbErr                  number;
    vchErrMsg               varchar2(512);
    cdplaca                 varchar2(15);
    feingreso               date;
    cdcia_usuaria           tzfw_usuarios.cdcia_usuaria%type;
    nmtransito_documento    number(20);
    cdtipo_documento        varchar2(3);
    cia_usuaria             tzfw_usuarios.cdcia_usuaria%type;
    cia_operadora           tzfw_usuarios.cdcia_usuaria%type;
    transito                varchar2(100);
    guia                    varchar2(100);
    porcentaje_peso         number;
    cdidentificacion        varchar2(10);
    nmdoctransporte         varchar2(25);
    nmtotal_doctransporte   number(5);
    xmlRecord          xmltype;
begin

    xmlRecord := xmltype(iclbRecord);

    cdplaca                                 := zfx_library.fvchgetString4XML(xmlRecord,'CDPLACA');
    feingreso                               := zfx_library.fdtegetDate4XML(xmlRecord,  'FEINGRESO');
    cdcia_usuaria                           := zfx_library.fvchgetString4XML(xmlRecord,'CDCIA_USUARIA');
    nmtransito_documento                    := zfx_library.fnmbgetNumber4XML(xmlRecord,'NMTRANSITO_DOCUMENTO');
    cdtipo_documento                        := zfx_library.fvchgetString4XML(xmlRecord,'CDTIPO_DOCUMENTO');
    cia_usuaria                             := zfx_library.fvchgetString4XML(xmlRecord,'CIA_USUARIA');
    cia_operadora                           := zfx_library.fvchgetString4XML(xmlRecord,'CIA_OPERADORA');
    cdidentificacion                        := zfx_library.fvchgetString4XML(xmlRecord,'CDIDENTIFICACION');
    transito                                := zfx_library.fvchgetString4XML(xmlRecord,'TRANSITO');
    guia                                    := zfx_library.fvchgetString4XML(xmlRecord,'GUIA');
    porcentaje_peso                         := zfx_library.fnmbgetNumber4XML(xmlRecord,'PORCENTAJE_PESO');
    nmdoctransporte                         := zfx_library.fvchgetString4XML(xmlRecord,'NMDOCTRANSPORTE');
    nmtotal_doctransporte                   := zfx_library.fnmbgetNumber4XML(xmlRecord,'NMTOTAL_DOCTRANSPORTE');

    if (instr(transito,cdtipo_documento) = 0 and cdcia_usuaria <> cia_operadora) then
           zfitzfw_documentos_x_cia.EvaluarGuia(nmbErr,vchErrMsg,cdplaca,feingreso,cdcia_usuaria,nmtransito_documento,
                                                cdtipo_documento,nmdoctransporte,nmtotal_doctransporte,cdidentificacion,guia,porcentaje_peso);

           if (nmbErr is not null) then
                Rollback;
                oclbXML := zfx_library.fclbsetMessage2XML(nmbErr, vchErrMsg);
                return;
          end if;
          commit;
          vchErrMsg := 'Operacion se completo con exito.';
          oclbXML := zfx_library.fclbsetMessage2XML(7, vchErrMsg);
          return;
    end if;

    return;
end ValidarUsuClficadoRegGuia;
--------------------------------------- ValidarGuiaUsuClfcado.prc -------------------------------------------------------------------
procedure ValidarGuiaUsuClfcado(
    iclbParam           in clob,
    oclbXML             out clob)
is
    nmbErr              number;
    vchErrMsg           varchar2(256);
    cdcia_usuaria       tzfw_usuarios.cdcia_usuaria%type;
    nmdocumento         varchar2(35);
    cdtipo_documento    varchar2(3);
    transito            varchar2(100);
    nmbultos_rel        number(5);
    nmpeso_rel          number(20,10);
    nmformulario_zf     tzfw_formularios.nmformulario_zf%type;

    snparcial                        tzfw_documentos_x_cia.snparcial%type;
    dsinconsistencias                tzfw_documentos_x_cia.dsinconsistencias%type;

    cdtransportadora    varchar2(5);
    dstransportadora    varchar2(100);
    nmvalor             number;

    xmlRecord           xmltype;
    tblXML              pttyXML;
begin
    xmlRecord := xmltype(iclbParam);

    cdcia_usuaria           := zfx_library.fvchgetString4XML(xmlRecord,'CDCIA_USUARIA');
    nmdocumento             := zfx_library.fvchgetString4XML(xmlRecord,'NMDOCUMENTO');
    cdtipo_documento        := zfx_library.fvchgetString4XML(xmlRecord,'CDTIPO_DOCUMENTO');
    transito                := zfx_library.fvchgetString4XML(xmlRecord,'TRANSITO');

    zfitzfw_documentos_x_cia.ValidarGuiaUsuClfcado(nmbErr,vchErrMsg,nmdocumento,cdcia_usuaria,cdtipo_documento,transito,nmbultos_rel,nmpeso_rel,
                                                   nmformulario_zf,cdtransportadora,dstransportadora,snparcial,dsinconsistencias,nmvalor);

    if (nmbErr is not null) then
        oclbXML := zfx_library.fclbsetMessage2XML(nmbErr, vchErrMsg);
        return;
    end if;

    tblXML(1).vchTag := 'NMBULTOS_REL';
    tblXML(1).vchValue := to_char(nmbultos_rel);
    tblXML(2).vchTag := 'NMPESO_REL';
    tblXML(2).vchValue := to_char(nmpeso_rel);
    tblXML(3).vchTag := 'NMFORMULARIO_ZF';
    tblXML(3).vchValue := to_char(nmformulario_zf);
    tblXML(4).vchTag := 'CDTRANSPORTADORA';
    tblXML(4).vchValue := to_char(cdtransportadora);
    tblXML(5).vchTag := 'DSTRANSPORTADORA';
    tblXML(5).vchValue := to_char(dstransportadora);
    tblXML(6).vchTag := 'SNPARCIAL';
    tblXML(6).vchValue := to_char(snparcial);
    tblXML(7).vchTag := 'DSINCONSISTENCIAS';
    tblXML(7).vchValue := to_char(dsinconsistencias);

    tblXML(8).vchTag := 'NMVALOR';
    tblXML(8).vchValue := to_char(nmvalor);
    oclbXML := zfx_library.fclbGetXML4Table(tblXML);
    return;
end ValidarGuiaUsuClfcado;

--------------------------------------- ValidarGuiaPlanilla.prc -------------------------------------------------------------------
procedure ValidarGuiaPlanilla(
    iclbParam           in clob,
    oclbXML             out clob)
is
    nmbErr              number;
    vchErrMsg           varchar2(256);
    cdcia_usuaria       tzfw_usuarios.cdcia_usuaria%type;
    nmdocumento         varchar2(35);
    cdtipo_documento    varchar2(3);
    transito            varchar2(100);
    nmbultos_rel        number(5);
    nmpeso_rel          number(20,10);
    nmformulario_zf     tzfw_formularios.nmformulario_zf%type;
  vcdplaca          tzfw_transitos_documentos.CDPLACA%type;
  nmtransito_doc     tzfw_transitos_documentos.nmtransito_documento%type;
    snparcial           tzfw_documentos_x_cia.snparcial%type;
    dsinconsistencias   tzfw_documentos_x_cia.dsinconsistencias%type;
    vfeingreso          tzfw_documentos_x_cia.feingreso%type;

    cdtransportadora    varchar2(5);
    dstransportadora    varchar2(100);
    nmvalor             number;

    xmlRecord           xmltype;
    tblXML              pttyXML;
begin
    xmlRecord := xmltype(iclbParam);

    cdcia_usuaria           := zfx_library.fvchgetString4XML(xmlRecord,'CDCIA_USUARIA');
    nmdocumento             := zfx_library.fvchgetString4XML(xmlRecord,'NMDOCUMENTO');
    cdtipo_documento        := zfx_library.fvchgetString4XML(xmlRecord,'CDTIPO_DOCUMENTO');
    transito                := zfx_library.fvchgetString4XML(xmlRecord,'TRANSITO');
    vcdplaca                := zfx_library.fvchgetString4XML(xmlRecord,'CDPLACA');
    nmtransito_doc          := zfx_library.fnmbgetNumber4XML(xmlRecord,'NMTRANSITO_DOCUMENTO');
    vfeingreso              := zfx_library.fdtegetDate4XML(xmlRecord,'FEINGRESO');

    zfitzfw_documentos_x_cia.ValidarGuiaPlanilla(nmbErr,vchErrMsg,nmdocumento,cdcia_usuaria,cdtipo_documento,vcdplaca,nmtransito_doc,vfeingreso,
                                                    transito,nmbultos_rel,nmpeso_rel,nmformulario_zf,cdtransportadora,dstransportadora,
                                                    snparcial,dsinconsistencias,nmvalor);

    if (nmbErr is not null) then
        oclbXML := zfx_library.fclbsetMessage2XML(nmbErr, vchErrMsg);
        return;
    end if;

    tblXML(1).vchTag := 'NMBULTOS_REL';
    tblXML(1).vchValue := to_char(nmbultos_rel);
    tblXML(2).vchTag := 'NMPESO_REL';
    tblXML(2).vchValue := to_char(nmpeso_rel);
    tblXML(3).vchTag := 'NMFORMULARIO_ZF';
    tblXML(3).vchValue := to_char(nmformulario_zf);
    tblXML(4).vchTag := 'CDTRANSPORTADORA';
    tblXML(4).vchValue := to_char(cdtransportadora);
    tblXML(5).vchTag := 'DSTRANSPORTADORA';
    tblXML(5).vchValue := to_char(dstransportadora);
    tblXML(6).vchTag := 'SNPARCIAL';
    tblXML(6).vchValue := to_char(snparcial);
    tblXML(7).vchTag := 'DSINCONSISTENCIAS';
    tblXML(7).vchValue := to_char(dsinconsistencias);

    tblXML(8).vchTag := 'NMVALOR';
    tblXML(8).vchValue := to_char(nmvalor);
    oclbXML := zfx_library.fclbGetXML4Table(tblXML);
    return;
end ValidarGuiaPlanilla;

--------------------------------------------------- UsuCalificadoCarga.prc ---------------------------------------------
procedure UsuCalificadoCarga(
    iclbParam           in clob,
    oclbXML             out clob)
is
    xmlParam            xmltype;
    xmlTab              xmltype;
    xmlTab1             xmltype;
    nmbCont             number;
    vchAction           varchar2(15);
    clbRowSrc           clob;
    clbRowSet           clob;
    clbRowSetMsg        clob;
    clbMessage          clob;
    nmbMsgCode          number;
    vchMsgDesc          varchar2(256);
    blnRowsErr          boolean;
    blnRowErr           boolean;
    nmbNew              number;
--=====================================================================================================================
procedure InsertTable$(
    ivchTag             in varchar2,
    ivchValue           in varchar2)
is
begin
    nmbNew                  := nmbNew +1;
    ptblNew(nmbNew).vchTag  := ivchTag;
    ptblNew(nmbNew).vchData := '<' || ivchTag || '>' || ivchValue || '</' || ivchTag || '>';
end InsertTable$;
------------------------------------------------------------------------------------------------------------------------
procedure ConcatMsg$
is
begin
    clbRowSrc := zfx_library.ConcatTagValue(clbRowSrc,'ROW','MSGDESCRIPTION',vchMsgDesc);
    clbRowSrc := zfx_library.ConcatTagValue(clbRowSrc,'ROW','MSGCODE',nmbMsgCode);
end ConcatMsg$;
------------------------------------------------------------------------------------------------------------------------
function LookupErr$
return boolean
is
    xmlMessage xmltype;
begin
    nmbMsgCode := null;
    vchMsgDesc := null;
    if (clbMessage is not null) then
        xmlMessage := xmltype(clbMessage);
        nmbMsgCode := zfx_library.fnmbgetNumber4XML(xmlMessage,'CODE');
        vchMsgDesc := zfx_library.fvchgetString4XML(xmlMessage,'DESCRIPTION','N');
    end if;
    return(nmbMsgCode is not null and nmbMsgCode <> 7);
end LookupErr$;
--=====================================================================================================================
begin
    xmlParam := xmltype(iclbParam);
    xmlTab := xmlParam.extract('/ROWSET');
    nmbCont := 1;
    nmbNew := 0;
    blnRowsErr := false;
    While(xmlTab.existsnode('//ROW[' || nmbCont || ']') = 1)
    loop
        zfx_library.XmlOpen$(xmlTab,'//ROW[' || nmbCont || ']',xmlTab1);
        clbMessage := null;
        clbRowSrc := xmltab1.getClobVal;
        zfx_library.XmlValue$(xmlTab1,'/ROW/DBX_ACTION/text()',cvhNotNull,vchAction);
        case vchAction
             when 'CREATE' then clbRowSet := '<ROWSET>'||clbRowSrc||'</ROWSET>';
                    zfxtzfw_documentos_x_cia.Insert$(clbRowSet,clbMessage);
             when 'UPDATE' then clbRowSet := '<ROWSET>'||clbRowSrc||'</ROWSET>';
                    zfxtzfw_documentos_x_cia.UpdateUsuCalificadoCarga(clbRowSet,clbMessage);
             when 'DELETE' then clbRowSet := '<ROWSET>'||clbRowSrc||'</ROWSET>';
                    zfxtzfw_documentos_x_cia.Delete$(clbRowSet,clbMessage);
             else null;
        end case;
        blnRowErr := LookupErr$;
        blnRowsErr := blnRowErr or blnRowsErr;
        ConcatMsg$;
        clbRowsetMsg := clbRowsetMsg || clbRowSrc;
        nmbCont := nmbCont +1;
    End loop;
    if (not blnRowsErr) then
        commit;
        ptblNew.delete;
        clbRowsetMsg := '<ROWSET>' || clbRowsetMsg ||'</ROWSET>'||chr(10);
        oclbXML := replace(clbRowsetMsg, '<DBX_ACTION>CREATE</DBX_ACTION>',
                                         '<DBX_ACTION>NONE</DBX_ACTION>');
        return;
    end if;
    Rollback;
    clbRowsetMsg := '<ROWSET>' || clbRowsetMsg ||'</ROWSET>'||chr(10);
    oclbXML := clbRowsetMsg;
    return;
end UsuCalificadoCarga;


--------------------------------------------------- Cargue$Excel.prc ---------------------------------------------
procedure Cargue$Excel(
    iclbParam           in clob,
    oclbXML             out clob)
is
    xmlParam            xmltype;
    xmlTab              xmltype;
    xmlTab1             xmltype;
    nmbCont             number;
    vchAction           varchar2(15);
    clbRowSrc           clob;
    clbRowSet           clob;
    clbRowSetMsg        clob;
    clbMessage          clob;
    nmbMsgCode          number;
    vchMsgDesc          varchar2(2000);
    blnRowsErr          boolean;
    blnRowErr           boolean;
    nmbNew              number;
    nerror              number;
--=====================================================================================================================
procedure InsertTable$(
    ivchTag             in varchar2,
    ivchValue           in varchar2)
is
begin
    nmbNew                  := nmbNew +1;
    ptblNew(nmbNew).vchTag  := ivchTag;
    ptblNew(nmbNew).vchData := '<' || ivchTag || '>' || ivchValue || '</' || ivchTag || '>';
end InsertTable$;
------------------------------------------------------------------------------------------------------------------------
procedure ConcatMsg$
is
begin
    clbRowSrc := zfx_library.ConcatTagValue(clbRowSrc,'ROW','MSGDESCRIPTION',vchMsgDesc);
    clbRowSrc := zfx_library.ConcatTagValue(clbRowSrc,'ROW','MSGCODE',nmbMsgCode);
end ConcatMsg$;
------------------------------------------------------------------------------------------------------------------------
function LookupErr$
return boolean
is
    xmlMessage xmltype;
begin
    nmbMsgCode := null;
    vchMsgDesc := null;
    if (clbMessage is not null) then
        xmlMessage := xmltype(clbMessage);
        nmbMsgCode := zfx_library.fnmbgetNumber4XML(xmlMessage,'CODE');
        vchMsgDesc := zfx_library.fvchgetString4XML(xmlMessage,'DESCRIPTION','N');
    end if;
    return(nmbMsgCode is not null and nmbMsgCode <> 7);
end LookupErr$;
--=====================================================================================================================
begin
    xmlParam := xmltype(iclbParam);
    xmlTab := xmlParam.extract('/ROWSET');
    nmbCont := 1;
    nmbNew := 0;
    blnRowsErr := false;
    While(xmlTab.existsnode('//ROW[' || nmbCont || ']') = 1) and blnRowsErr = false
    loop
        zfx_library.XmlOpen$(xmlTab,'//ROW[' || nmbCont || ']',xmlTab1);
        clbMessage := null;
        clbRowSrc := xmltab1.getClobVal;
        zfx_library.XmlValue$(xmlTab1,'/ROW/DBX_ACTION/text()',cvhNotNull,vchAction);

        clbRowSet := '<ROWSET>'||clbRowSrc||'</ROWSET>';
        zfxtzfw_documentos_x_cia.Insert$Excel(clbRowSet,clbMessage);

        blnRowErr := LookupErr$;
        blnRowsErr := blnRowErr or blnRowsErr;
        ConcatMsg$;
        clbRowsetMsg := clbRowsetMsg || clbRowSrc;
        nmbCont := nmbCont +1;

        if(blnRowsErr)then
            Rollback;
            clbRowsetMsg :=  clbMessage ||chr(10);
            oclbXML := clbRowsetMsg;
        return;
        end if;
    End loop;

    if (not blnRowsErr) then
                commit;
        ptblNew.delete;
        clbRowsetMsg := clbMessage||chr(10);
        oclbXML := replace(clbRowsetMsg, '<DBX_ACTION>CREATE</DBX_ACTION>',
                                         '<DBX_ACTION>NONE</DBX_ACTION>');
        return;
    end if;
    clbRowsetMsg := '<ROWSET>' || clbMessage ||'</ROWSET>'||chr(10);
    oclbXML := clbRowsetMsg;

    return;
end Cargue$Excel;
------------------------------------------------------ Insert$Excel.prc ----------------------------------------------------
procedure Insert$Excel(
    iclbRecord          in      clob,
    oclbXML             out     clob)
is
    rcrRecord               rtytzfw_documentos_x_cia;
    nmbErr                  number;
    vchErrMsg               varchar2(2000);
    xmlRecord               xmltype;
    vtrnsito_doctrans       varchar2(20);
    vcampos                 varchar2(2000);
    porcentaje_peso         number;
    vfecha_ingreso          varchar2(20);
    transito                tzfw_parametros.dsvalor%type;
    cia_operadora           tzfw_parametros.dsvalor%type;
    guia                    tzfw_parametros.dsvalor%type;
    cdtipo_documento        tzfw_transitos_documentos.cdtipo_documento%type;
    cdidentificacion        tzfw_transitos_documentos.cdusuario_aud%type;
    nmdoctransporte         tzfw_transitos_documentos.nmdoctransporte%type;
    nmtotal_doctransporte   tzfw_transitos_documentos.nmtotal_doctransporte%type;
    NMTRANSITODOCUMENTO     tzfw_transitos_documentos.nmtransito_documento%type;
    nmbExiste_Dto_x_Cia     number := 0;
begin

    xmlRecord := xmltype(iclbRecord);


    rcrRecord.cdplaca                       := zfx_library.fvchgetString4XML(xmlRecord,'CDPLACA');
--    rcrRecord.feingreso                     := zfx_library.fdtegetDate4XML(xmlRecord,  'FEINGRESO');
    vfecha_ingreso                          := zfx_library.fvchgetString4XML(xmlRecord,'FEINGRESO');
    rcrRecord.cdcia_usuaria                 := zfx_library.fvchgetString4XML(xmlRecord,'CDCIA_USUARIA');
    vtrnsito_doctrans                       := zfx_library.fvchgetString4XML(xmlRecord,'NMTRANSITO_DOCUMENTO');
    rcrRecord.nmconsecutivo_doc             := zfx_library.fnmbgetNumber4XML(xmlRecord,'NMCONSECUTIVO_DOC');
    rcrRecord.nmcontenedores                := zfx_library.fvchgetString4XML(xmlRecord,'NMCONTENEDORES');
    rcrRecord.nmbultos_rel                  := zfx_library.fnmbgetNumber4XML(xmlRecord,'NMBULTOS_REL');
    rcrRecord.nmbultos_rec                  := zfx_library.fnmbgetNumber4XML(xmlRecord,'NMBULTOS_REC');
    rcrRecord.nmbultos_pla                  := zfx_library.fnmbgetNumber4XML(xmlRecord,'NMBULTOS_PLA');
    rcrRecord.nmpeso_rel                    := zfx_library.fnmbgetNumber4XML(xmlRecord,'NMPESO_REL');
    rcrRecord.nmpeso_rec                    := zfx_library.fnmbgetNumber4XML(xmlRecord,'NMPESO_REC');
    rcrRecord.nmpeso_pla                    := zfx_library.fnmbgetNumber4XML(xmlRecord,'NMPESO_PLA');
    rcrRecord.nmformulario_zf               := zfx_library.fvchgetString4XML(xmlRecord,'NMFORMULARIO_ZF');
    rcrRecord.cdtransportadora              := zfx_library.fvchgetString4XML(xmlRecord,'CDTRANSPORTADORA');
    rcrRecord.lsclase_mcia                  := zfx_library.fvchgetString4XML(xmlRecord,'LSCLASE_MCIA');
    rcrRecord.lsestado_mcia                 := zfx_library.fvchgetString4XML(xmlRecord,'LSESTADO_MCIA');
    rcrRecord.dsobservacion                 := zfx_library.fvchgetString4XML(xmlRecord,'DSOBSERVACION');
    rcrRecord.nmdocumento                   := zfx_library.fvchgetString4XML(xmlRecord,'NMDOCUMENTO');
    rcrRecord.dsmercancia                   := zfx_library.fvchgetString4XML(xmlRecord,'DSMERCANCIA');
    rcrRecord.nmtara_contenedor             := zfx_library.fnmbgetNumber4XML(xmlRecord,'NMTARA_CONTENEDOR');
    rcrRecord.snparcial                     := zfx_library.fvchGetString4XML(xmlRecord,'SNPARCIAL');
    rcrRecord.dsinconsistencias             := zfx_library.fvchGetString4XML(xmlRecord,'DSINCONSISTENCIAS');
    rcrRecord.cdusuario_reg                 := zfx_library.fvchGetString4XML(xmlRecord,'CDUSUARIO');
    guia                                    := zfx_library.fvchgetString4XML(xmlRecord,'GUIA');
    porcentaje_peso                         := zfx_library.fnmbgetNumber4XML(xmlRecord,'PORCENTAJE_PESO');
    vcampos                                 := zfx_library.fvchgetString4XML(xmlRecord,'CAMPOSCONVALOR');    

    zfstzfw_documentos_x_cia.Valid_Existe_Dto_x_Cia(nmbErr, vchErrMsg, nmbExiste_Dto_x_Cia, rcrRecord, vfecha_ingreso);
      
    if nmbExiste_Dto_x_Cia > 0 then
       zfstzfw_documentos_x_cia.Update$Excel(nmbErr, vchErrMsg, rcrRecord,guia,porcentaje_peso,vtrnsito_doctrans,vcampos,vfecha_ingreso);
    else
       zfstzfw_documentos_x_cia.Insert$Excel(nmbErr, vchErrMsg, rcrRecord,guia,porcentaje_peso,vtrnsito_doctrans,vcampos,vfecha_ingreso);
    end if; 
    if (nmbErr is not null) then
        if(nmbErr=152)then
            vchErrMsg:=vchErrMsg||' : '||vtrnsito_doctrans;
        elsif(nmbErr=153)then
            vchErrMsg:=vchErrMsg||' transito/tipo documento : '||vtrnsito_doctrans;
        elsif(nmbErr=154)then
            vchErrMsg:=vchErrMsg||rcrRecord.cdcia_usuaria;
        elsif(nmbErr=155)then
            vchErrMsg:=vchErrMsg||' placa: '||rcrRecord.cdplaca;
        elsif(nmbErr=156)then
            vchErrMsg:=vchErrMsg||' cd_usuaria: '||rcrRecord.cdcia_usuaria;
        elsif(nmbErr=157)then
            vchErrMsg:=vchErrMsg||' numero_transito: '||rcrRecord.nmtransito_documento;
        elsif(nmbErr=158)then
            vchErrMsg:=vchErrMsg||' formulario: '||rcrRecord.nmformulario_zf;
        elsif(nmbErr=159)then
            vchErrMsg:=vchErrMsg||' formulario: '||rcrRecord.nmformulario_zf||' no puede estar asociado a mas de una placa ';
        elsif(nmbErr=160)then
            vchErrMsg:=vchErrMsg||' formulario: '||rcrRecord.nmformulario_zf||' es tipo PROVISIONAL o DEFINITIVO, no puede ser utilizado. ';
         elsif(nmbErr=161)then
            vchErrMsg:=vchErrMsg||' El formulario: '||rcrRecord.nmformulario_zf||' asociado al tipo de ingreso '||vtrnsito_doctrans||' se utiliza en otro tipo de ingreso o viene en otro tipo de ingreso en el archivo ';
        end if;
        vchErrMsg := TRANSLATE(vchErrMsg,'����������������������������������������������',
                             'aeiouaeiouaoaeiooaeioucAEIOUAEIOUAOAEIOOAEIOUC');
        oclbXML := zfx_library.fclbsetMessage2XML(nmbErr, vchErrMsg);
        return;
    end if;
    vchErrMsg := 'Operacion se completo con exito.';
    oclbXML := zfx_library.fclbsetMessage2XML(7, vchErrMsg);


    begin
       select dsvalor into transito from tzfw_parametros where dsparametro='TRANSITO';
    exception
      when no_data_found then null;
    end;

    begin
       select dsvalor into cia_operadora from tzfw_parametros where dsparametro='COMPANIA_OPERADORA';
    exception
      when no_data_found then null;
    end;

     begin
          select CDTIPO_DOCUMENTO,CDUSUARIO_AUD,NMDOCTRANSPORTE,NMTOTAL_DOCTRANSPORTE, NMTRANSITO_DOCUMENTO
          into cdtipo_documento, cdidentificacion,nmdoctransporte, nmtotal_doctransporte, NMTRANSITODOCUMENTO
          from tzfw_transitos_documentos x
          where cdplaca =rcrRecord.cdplaca
          and feingreso =to_date(vfecha_ingreso,'YYYY/MM/DD HH24:MI:SS')
          and cdcia_usuaria = rcrRecord.cdcia_usuaria
          and nvl(x.nmtransito,nmdoctransporte) =vtrnsito_doctrans;
     exception
      when no_data_found then
        vchErrMsg := 'No existe el transito en la tabla tzfw_transitos_documentos';
        oclbXML := zfx_library.fclbsetMessage2XML(7, vchErrMsg);
        return;
    end;
    if (instr(transito,cdtipo_documento) = 0 and rcrRecord.cdcia_usuaria <> cia_operadora) then
           zfitzfw_documentos_x_cia.EvaluarGuia(nmbErr,vchErrMsg,rcrRecord.cdplaca,to_date(vfecha_ingreso,'YYYY/MM/DD HH24:MI:SS'),rcrRecord.cdcia_usuaria,NMTRANSITODOCUMENTO,
                                                cdtipo_documento,nmdoctransporte,nmtotal_doctransporte,cdidentificacion,guia,porcentaje_peso,1);

           if (nmbErr is not null and nmbErr !=132) then
              --  Rollback;
                vchErrMsg := TRANSLATE(vchErrMsg,'����������������������������������������������',
                             'aeiouaeiouaoaeiooaeioucAEIOUAEIOUAOAEIOOAEIOUC');
                oclbXML := zfx_library.fclbsetMessage2XML(nmbErr, vchErrMsg);
                return;
          end if;
--          commit;
          if nmbErr is null then vchErrMsg := 'Operacion se completo con exito.'; end if;
          if nmbErr =132 then
              vchErrMsg := TRANSLATE(vchErrMsg,'����������������������������������������������',
                          'aeiouaeiouaoaeiooaeioucAEIOUAEIOUAOAEIOOAEIOUC');
          end if;
          oclbXML := zfx_library.fclbsetMessage2XML(7, vchErrMsg);
          return;
    end if;

    if (instr(transito,cdtipo_documento) > 0 and rcrRecord.cdcia_usuaria <> cia_operadora) then

          zfitzfw_documentos_x_cia.ValidarNumRegUsuClfcado(nmbErr,vchErrMsg,rcrRecord.cdplaca,to_date(vfecha_ingreso,'YYYY/MM/DD HH24:MI:SS'),rcrRecord.cdcia_usuaria,NMTRANSITODOCUMENTO,transito,cdidentificacion,1);

          if (nmbErr is not null) then
              --  Rollback;
                vchErrMsg := TRANSLATE(vchErrMsg,'����������������������������������������������',
                             'aeiouaeiouaoaeiooaeioucAEIOUAEIOUAOAEIOOAEIOUC');
                oclbXML := zfx_library.fclbsetMessage2XML(nmbErr, vchErrMsg);
                return;
          end if;

          zfitzfw_documentos_x_cia.ActualizarFrm(nmbErr,vchErrMsg,rcrRecord.cdplaca,to_date(vfecha_ingreso,'YYYY/MM/DD HH24:MI:SS'),rcrRecord.cdcia_usuaria,NMTRANSITODOCUMENTO,
                                                 cdtipo_documento,transito,cdidentificacion,1);
          if (nmbErr is not null) then
              --  Rollback;
                vchErrMsg := TRANSLATE(vchErrMsg,'����������������������������������������������',
                             'aeiouaeiouaoaeiooaeioucAEIOUAEIOUAOAEIOOAEIOUC');
                oclbXML := zfx_library.fclbsetMessage2XML(nmbErr, vchErrMsg);
                return;
          end if;
         -- commit;
          vchErrMsg := 'Operacion se completo con exito.';
          oclbXML := zfx_library.fclbsetMessage2XML(7, vchErrMsg);
          return;
    end if;

    return;
end Insert$Excel;

------------------------------------------------------ ValidarTotalDoc.prc ----------------------------------------------------
procedure ValidarTotalDoc(
    iclbRecord          in      clob,
    onmbTotalDoc        out     number)
is
    rcrRecord          rtytzfw_documentos_x_cia;
    nmbErr             number;
    vchErrMsg          varchar2(500);
    xmlRecord          xmltype;
begin

    xmlRecord := xmltype(iclbRecord);

    rcrRecord.cdplaca                    := zfx_library.fvchgetString4XML(xmlRecord,'CDPLACA');
    rcrRecord.cdcia_usuaria              := zfx_library.fvchgetString4XML(xmlRecord,'CDCIA_USUARIA');
    rcrRecord.feingreso                  := zfx_library.fdtegetDate4XML(xmlRecord,'FEINGRESO');

    zfstzfw_documentos_x_cia.ValidarTotalDoc(rcrRecord,onmbTotalDoc);

    return;
end ValidarTotalDoc;

--=====================================================================================================================

----------------------------------------------------------- ValDoc_x_Cia.prc ---------------------------------------
/****************************************************************************************

    Ver        Fecha       Autor              Descripcion
    ---------  ----------  ---------------    ------------------------------------

     4.0        20190225    Guillermo Prieto   Modificacion del paquete para incluir la validacion
                                              para el desarrollo del Req 11: Reporte  Estado Planillas
                                              se debe validar que si se  digita la compania y el documento debe validar
                                              que ese documento corresponda a la compania, para esto se crea el
                                              procedimiento ValDoc_x_Cia.
*****************************************************************************************/
procedure ValDoc_x_Cia(
    iclbRecord          in      clob,
    oclbXML             out     clob)
is
    nmbErr                       number;
    vchErrMsg                    varchar2(2000);
    xmlRecord                    xmltype;
    clbXMLResult                 clob;
    vchCdcia_Usuaria             tzfw_documentos_x_cia.CDCIA_USUARIA%type;
    nmb_nmDocumento              tzfw_documentos_x_cia.NMDOCUMENTO%type;
    nmbValExistDoc_x_Cia         number   :=0;
    vchcdestado                  varchar2(10)  := ' ';
    nmbResult                    number;


begin
    xmlRecord := xmltype(iclbRecord);
    --rcrRecord := iclbRecord;

    vchCdcia_Usuaria                    := zfx_library.fvchgetString4XML(xmlRecord,  'CDCIA_USUARIA');
    nmb_nmDocumento                     := zfx_library.fvchgetString4XML(xmlRecord,  'NMDOCUMENTO');

    zfstzfw_documentos_x_cia.ValDoc_x_Cia(nmbErr, vchErrMsg, vchCdcia_Usuaria, nmb_nmDocumento,  nmbValExistDoc_x_Cia);



/****************************************************************************************

    Ver        Fecha       Autor              Descripcion
    ---------  ----------  ---------------    ------------------------------------

     4.0        20190225    Guillermo Prieto   Modificacion del paquete para incluir la validacion
                                              para el desarrollo del Req 11: Reporte  Estado Planillas
                                              se debe validar que si se  digita la compania y el documento debe validar
                                              que ese documento corresponda a la compania, para esto se crea el
                                              procedimiento ValDoc_x_Cia.
*****************************************************************************************/

    if ( nmbValExistDoc_x_Cia = 0) then
            nmbErr := 0;
            vchErrMsg := ' ';
            oclbXML := zfx_library.fclbsetMessage2XML(nmbErr, vchErrMsg);
            return;
    elsif ( nmbValExistDoc_x_Cia = 1) then
            nmbErr := 1;
            vchErrMsg := ' ';
            oclbXML := zfx_library.fclbsetMessage2XML(nmbErr, vchErrMsg);
            return;
    end if;

    if (nmbResult=-1)then
        oclbXML := zfx_library.fclbsetMessage2XML(-1, ' ');
        oclbXML := zfx_library.fclbsetMessage2XML(nmbErr, vchErrMsg);
        return;
    end if;

    return;
end ValDoc_x_Cia;

--=====================================================================================================================

----------------------------------------------------------- ValDoc_x_Fmm.prc ---------------------------------------
/****************************************************************************************

    Ver        Fecha       Autor              Descripcion
    ---------  ----------  ---------------    ------------------------------------

     4.0        20190225    Guillermo Prieto   Modificacion del paquete para incluir la validacion
                                              para el desarrollo del Req 11: Reporte  Estado Planillas
                                              se debe validar que si se  digita la compania y el documento debe validar
                                              que ese documento corresponda a la compania, para esto se crea el
                                              procedimiento ValDoc_x_Cia.
                                              se debe validar que si se  digita el n�mero de formulario y el numero de documento,
                                              debe validar que ese documento corresponda al formulario, para esto se crea el
                                              procedimiento ValDoc_x_Fmm.
*****************************************************************************************/
procedure ValDoc_x_Fmm(
    iclbRecord          in      clob,
    oclbXML             out     clob)
is
    nmbErr                       number;
    vchErrMsg                    varchar2(2000);
    xmlRecord                    xmltype;
    clbXMLResult                 clob;
    nmb_nmFormulario_ZF          tzfw_documentos_x_cia.NMFORMULARIO_ZF%type;
    nmb_nmDocumento              tzfw_documentos_x_cia.NMDOCUMENTO%type;
    nmbValExistDoc_x_Fmm         number   :=0;
    vchcdestado                  varchar2(10)  := ' ';
    nmbResult                    number;

begin
    xmlRecord := xmltype(iclbRecord);
    --rcrRecord := iclbRecord;

    nmb_nmFormulario_ZF                 := zfx_library.fvchgetString4XML(xmlRecord,  'NMFORMULARIO_ZF');
    nmb_nmDocumento                     := zfx_library.fvchgetString4XML(xmlRecord,  'NMDOCUMENTO');

    zfstzfw_documentos_x_cia.ValDoc_x_Fmm(nmbErr, vchErrMsg, nmb_nmFormulario_ZF, nmb_nmDocumento,  nmbValExistDoc_x_Fmm);



/****************************************************************************************

    Ver        Fecha       Autor              Descripcion
    ---------  ----------  ---------------    ------------------------------------

     4.0        20190225    Guillermo Prieto  Modificacion del paquete para incluir la validacion
                                              para el desarrollo del Req 11: Reporte  Estado Planillas
                                              se debe validar que si se  digita la compania y el documento debe validar
                                              que ese documento corresponda a la compania, para esto se crea el
                                              procedimiento ValDoc_x_Cia.
                                              se debe validar que si se  digita el n�mero de formulario y el numero de documento,
                                              debe validar que ese documento corresponda al formulario, para esto se crea el
                                              procedimiento ValDoc_x_Fmm.
*****************************************************************************************/

    if ( nmbValExistDoc_x_Fmm = 0) then
            nmbErr := 0;
            vchErrMsg := ' ';
            oclbXML := zfx_library.fclbsetMessage2XML(nmbErr, vchErrMsg);
            return;
    elsif ( nmbValExistDoc_x_Fmm = 1) then
            nmbErr := 1;
            vchErrMsg := ' ';
            oclbXML := zfx_library.fclbsetMessage2XML(nmbErr, vchErrMsg);
            return;
    end if;

    if (nmbResult=-1)then
        oclbXML := zfx_library.fclbsetMessage2XML(-1, ' ');
        oclbXML := zfx_library.fclbsetMessage2XML(nmbErr, vchErrMsg);
        return;
    end if;

    return;
end ValDoc_x_Fmm;

--=====================================================================================================================

----------------------------------------------------------- ValDoc_x_Fmm_x_Cia.prc ---------------------------------------
/****************************************************************************************

    Ver        Fecha       Autor              Descripcion
    ---------  ----------  ---------------    ------------------------------------

     4.0        20190225    Guillermo Prieto   Modificacion del paquete para incluir la validacion
                                              para el desarrollo del Req 11: Reporte  Estado Planillas
                                              se debe validar que si se  digita la compania y el documento debe validar
                                              que ese documento corresponda a la compania, para esto se crea el
                                              procedimiento ValDoc_x_Cia.
                                              se debe validar que si se  digita el n�mero de formulario y el numero de documento,
                                              debe validar que ese documento corresponda al formulario, para esto se crea el
                                              procedimiento ValDoc_x_Fmm.
                                              se debe validar que si se  digita la compania, el n�mero de formulario y el numero de documento,
                                              debe validar que los tres correspondan al formulario, para esto se crea el
                                              procedimiento ValDoc_x_Fmm_x_Cia.
*****************************************************************************************/
procedure ValDoc_x_Fmm_x_Cia(
    iclbRecord          in      clob,
    oclbXML             out     clob)
is
    nmbErr                       number;
    vchErrMsg                    varchar2(2000);
    xmlRecord                    xmltype;
    clbXMLResult                 clob;
    vchCdcia_Usuaria             tzfw_documentos_x_cia.CDCIA_USUARIA%type;
    nmb_nmFormulario_ZF          tzfw_documentos_x_cia.NMFORMULARIO_ZF%type;
    nmb_nmDocumento              tzfw_documentos_x_cia.NMDOCUMENTO%type;
    nmbValExistDoc_x_Fmm_x_Cia   number   :=0;
    vchcdestado                  varchar2(10)  := ' ';
    nmbResult                    number;

begin
    xmlRecord := xmltype(iclbRecord);
    --rcrRecord := iclbRecord;

    vchCdcia_Usuaria                    := zfx_library.fvchgetString4XML(xmlRecord,  'CDCIA_USUARIA');
    nmb_nmFormulario_ZF                 := zfx_library.fvchgetString4XML(xmlRecord,  'NMFORMULARIO_ZF');
    nmb_nmDocumento                     := zfx_library.fvchgetString4XML(xmlRecord,  'NMDOCUMENTO');

    zfstzfw_documentos_x_cia.ValDoc_x_Fmm_x_Cia(nmbErr, vchErrMsg, vchCdcia_Usuaria, nmb_nmFormulario_ZF, nmb_nmDocumento,  nmbValExistDoc_x_Fmm_x_Cia);



/****************************************************************************************

    Ver        Fecha       Autor              Descripcion
    ---------  ----------  ---------------    ------------------------------------

     4.0        20190225    Guillermo Prieto  Modificacion del paquete para incluir la validacion
                                              para el desarrollo del Req 11: Reporte  Estado Planillas
                                              se debe validar que si se  digita la compania y el documento debe validar
                                              que ese documento corresponda a la compania, para esto se crea el
                                              procedimiento ValDoc_x_Cia.
                                              se debe validar que si se  digita el n�mero de formulario y el numero de documento,
                                              debe validar que ese documento corresponda al formulario, para esto se crea el
                                              procedimiento ValDoc_x_Fmm.
                                              se debe validar que si se  digita la compania, el n�mero de formulario y el numero de documento,
                                              debe validar que los tres correspondan al formulario, para esto se crea el
                                              procedimiento ValDoc_x_Fmm_x_Cia.
*****************************************************************************************/

    if ( nmbValExistDoc_x_Fmm_x_Cia = 0) then
            nmbErr := 0;
            vchErrMsg := ' ';
            oclbXML := zfx_library.fclbsetMessage2XML(nmbErr, vchErrMsg);
            return;
    elsif ( nmbValExistDoc_x_Fmm_x_Cia = 1) then
            nmbErr := 1;
            vchErrMsg := ' ';
            oclbXML := zfx_library.fclbsetMessage2XML(nmbErr, vchErrMsg);
            return;
    end if;

    if (nmbResult=-1)then
        oclbXML := zfx_library.fclbsetMessage2XML(-1, ' ');
        oclbXML := zfx_library.fclbsetMessage2XML(nmbErr, vchErrMsg);
        return;
    end if;

    return;
end ValDoc_x_Fmm_x_Cia;

--=====================================================================================================================
begin
    null;
end zfxtzfw_documentos_x_cia;
