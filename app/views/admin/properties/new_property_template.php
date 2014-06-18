<script id="newPropForm" type="text/template">
    <?php echo Form::open(array('route'=>'admin.propstr', 'class' => 'form-horizontal', 'id' => 'form-add-prop'))?>
    <% if(e){ %>
    <input type="hidden" name="id" value="<%=e%>">
    <% } %>
    <div class="messages"></div>
    <div class="row">
        <% for (i in s) { %>
        <div class="<%=s[i][0]%>">
            <% groups = s[i].groups; %>
            <% for (g in groups) { %>
                <% gr = groups[g]; %>
                    <%
                    var attr = '';
                    for (a in gr.attr){
                        attr+= ' '+a+'="'+gr.attr[a]+'"'
                    }
                    attr += ('undefined'!==typeof l[gr.label + '_p']?' placeholder="'+l[gr.label + '_p']+'"':'');
                    
                    getVisible = function(){
                        if ('object' == typeof gr.visible){
                            var vmdl = gr.visible.model;
                            var vval = gr.visible.data;
                            
                            if (vmdl && vval){
                                
                                vval = vval.split('.');
                                vvaltmp = d;
                                for (vvali in vval){
                                    vvaltmp = vvaltmp[vval[vvali]] || false;
                                    if (!vvaltmp){
                                        return '';
                                    }
                                }
                                var vmdltmp = s;
                                vval = vvaltmp;
                                vmdl = vmdl.split('.');
                                for (vmdli in vmdl){
                                    var vmdlip = vmdl[vmdli];
                                    
                                    if (vmdlip == '%d'){
                                        vmdlip = ('number' == typeof vmdlip ? parseInt(vval) : vval);
                                    }
                                    
                                    if ('undefined' == typeof vmdltmp[vmdlip]){
                                        return '';
                                    }
                                    
                                    vmdltmp = vmdltmp[vmdlip];
                                }
                                
                                if (!vmdltmp){
                                    return ' style="display:none"';
                                }
                            }
                            
                            return '';
                        }
                    };
                    
                    var visible = getVisible();
                    
                    %>
                <div class="form-group"<%=visible%>>
                    <?php /* Get Label from Language Variable by index */ ?>
                    <label><%=l[gr.label]%></label>
                    
                    <?php /* TEXT */ ?>
                    <% if(gr._input){ %>
                    <?php /* Get Label from Language Variable by index */ ?>
                    <% var frmVal = d[gr.label] || ''; %>
                    <input<%=attr%> value="<%=frmVal%>"/>
                    <% } %>
                    
                    <?php /* TEXTAREA */ ?>
                    <% if(gr._textarea){ %>
                    <% var frmVal = d[gr.label] || ''; %>
                    <textarea<%=attr%>><%=frmVal%></textarea>
                    <% } %>
                    
                    <?php /* SELECT */ ?>
                    <% if(gr._select){ %>
                    <select<%=attr%>>
                        <% var slDefault = gr.default || ''; %>
                        <option <%=('disabled' == slDefault ? slDefault : 'value="' + slDefault + '"')%>><%=(l[gr.label + '_d'] || l[gr.label + '_p'])%></option>
                        <% for (gi in gr.options){ %>
                        <% var selLabel = (gr.isObject ? gr.options[gi][gr.labelKey] : gr.options[gi]); %>
                        <% var incAttrs = ''; if ('object' == typeof gr.inclData){ for (ind in gr.inclData) {incAttrs += ' data-' + gr.inclData[ind] + '="' + gr.options[gi][gr.inclData[ind]] + '"'}} %>
                                               <?php /* Find the current value from data array values if exists */ ?>
                        <option value="<%=gi%>"<%=incAttrs%> <%=('object' == typeof d[gr.label] && d[gr.label].indexOf(parseInt(gi)) > -1 ?' selected="selected"':'')%>><%=selLabel%></option>
                        <% } %>
                    </select>
                    <% } %>
                    
                </div>
            <% } %>
        </div>
        <% } %>
    </div>
    <div class="row">
    <div class="modal-footer">
        <button data-dismiss="modal" class="btn btn-default" type="button" id="admin_prop_add_close">Close</button>
        <% if(!e){ %>
        <button class="btn btn-primary" name="add" id="pabsmt" type="submit"><?php echo Lang::get('ui.add_property') ?></button>
        <% } else { %>
        <button class="btn btn-primary" name="add" id="pabsmt" type="submit"><?php echo Lang::get('ui.update') ?></button>
        <% } %>
    </div>
    <?php echo Form::close() ?>
</div>
</script>