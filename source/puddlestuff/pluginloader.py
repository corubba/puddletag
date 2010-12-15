# -*- coding: utf-8 -*-
import os, traceback, sys
from puddlestuff.puddleobjects import PuddleConfig, winsettings
from puddlestuff.constants import (FUNCTIONS, TAGSOURCE, SAVEDIR,
    DIALOGS, MUSICLIBS)
from os.path import splitext, exists

from PyQt4.QtCore import *
from PyQt4.QtGui import *

NAME = 'name'
AUTHOR = 'author'
DESC = 'description'
PT_VERSION = 'puddletag_version'
VERSION = 'version'
INFO_SECTION = 'info'
MODULE_NAME = 'module'

PLUGIN_DIRS = [os.path.join(SAVEDIR, u'plugins')]

PROPERTIES = [NAME, AUTHOR, DESC, PT_VERSION, VERSION]

def get_plugins(plugindir):
    if not os.path.exists(plugindir):
        os.makedirs(plugindir)
    infos = []
    for module in os.listdir(plugindir):
        info_path = os.path.join(plugindir, module, 'info')
        if not exists(info_path):
            continue
        cparser = PuddleConfig(info_path)
        values = [cparser.get(INFO_SECTION, prop, '') for prop in PROPERTIES]
        if len(filter(None, values)) < len(PROPERTIES):
            continue
        d = dict(zip(PROPERTIES, values))
        d[MODULE_NAME] = module
        infos.append(d)
    return infos

def load_plugins(plugins=None):
    [sys.path.insert(0, d) for d in PLUGIN_DIRS]
    cparser = PuddleConfig()
    to_load = cparser.get('plugins', 'to_load', [])
    functions = {}
    tagsources = []
    dialogs = []
    musiclibs = []
    join = os.path.join
    if plugins is None:
        plugins = []
        [plugins.extend(get_plugins(d)) for d in PLUGIN_DIRS]

    for plugin in plugins:
        if plugin[MODULE_NAME] not in to_load:
            continue
        try:
            module = __import__(plugin[MODULE_NAME])
        except:
            print u'Failed to load plugin: %s', plugin['name']
            traceback.print_exc()
            continue
        if hasattr(module, 'functions'):
            functions.update(module.functions)

        if hasattr(module, 'tagsources'):
            tagsources.extend(module.tagsources)

        if hasattr(module, 'dialogs'):
            dialogs.extend(module.dialogs)

        if hasattr(model, 'musiclibs'):
            musiclibs.extend(module.musiclibs)
        
    for d in PLUGIN_DIRS:
        del(sys.path[0])

    return {FUNCTIONS: functions, TAGSOURCE: tagsources, DIALOGS: dialogs,
        MUSICLIBS: musiclibs}

class InfoWidget(QLabel):
    def __init__(self, info=None, parent=None):
        super(InfoWidget, self).__init__(parent)
        self.setAlignment(Qt.AlignLeft | Qt.AlignTop)
        self.setWordWrap(True)
        if info:
            self.changeInfo(info)
    
    def changeInfo(self, info):
        labels = ['Name', 'Author', 'Description', 'Version']
        properties = [NAME, AUTHOR, DESC, VERSION]
        
        text = u'<br />'.join([u'<b>%s:</b> %s' % (disp, info[prop]) for 
            disp, prop in zip(labels, properties)])
        self.setText(text)

class PluginConfig(QDialog):
    def __init__(self, parent = None):
        super(PluginConfig, self).__init__(parent)
        winsettings('pluginconfig', self)
        self._listbox = QListWidget()
        info_display = InfoWidget()
        
        hbox = QHBoxLayout()
        hbox.addWidget(self._listbox, 0)
        hbox.addWidget(info_display, 1)
        
        vbox = QVBoxLayout()
        vbox.addLayout(hbox)
        vbox.addWidget(
            QLabel('<b>Loading/unloading plugins requires a restart.</b>'))
        self.setLayout(vbox)

        plugins = []
        [plugins.extend(get_plugins(d)) for d in PLUGIN_DIRS]
        
        cparser = PuddleConfig()
        to_load = cparser.get('plugins', 'to_load', [])
        for plugin in plugins:
            item = QListWidgetItem()
            item.setText(plugin[NAME])
            if plugin[MODULE_NAME] in to_load:
                item.setCheckState(Qt.Checked)
            else:
                item.setCheckState(Qt.Unchecked)
            item.plugin = plugin
            self._listbox.addItem(item)
        
        self.connect(self._listbox, 
            SIGNAL('currentItemChanged(QListWidgetItem*, QListWidgetItem *)'),
            lambda item, previous: info_display.changeInfo(item.plugin))
    
    def get_to_load(self):
        to_load = []
        for row in range(self._listbox.count()):
            item = self._listbox.item(row)
            if item.checkState() == Qt.Checked:
                to_load.append(item.plugin[MODULE_NAME])
        return to_load
    
    def applySettings(self, control=None):
        to_load = self.get_to_load()
        cparser = PuddleConfig()
        cparser.set('plugins', 'to_load', to_load)

if __name__ == '__main__':
    app = QApplication([])
    win = PluginConfig()
    win.show()
    app.exec_()