import re
src='src/'
css=open(src+'style.css').read()
js='\n'.join(open(src+f).read().replace("if (typeof module !== 'undefined')","if (false)") for f in ['engine_sh102.js','model.js','render3d.js','files.js','i18n.js','app.js'])
html=open(src+'index.tpl.html').read().replace('/*CSS*/',css).replace('/*JS*/',js.replace('</script','<\\/script'))
import os; os.makedirs('dist',exist_ok=True)
open('dist/index.html','w').write(html)
print(len(html))
