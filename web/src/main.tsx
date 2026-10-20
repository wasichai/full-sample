import { createRoot } from 'react-dom/client'
import { WasichaiApp } from '@wasichai/core'
import { automationModule } from '@wasichai/automation'
import { documentsModule } from '@wasichai/documents'
import { formsModule } from '@wasichai/forms'
import { gisModule } from '@wasichai/gis'
import { pagesModule } from '@wasichai/pages'
import { viewsModule } from '@wasichai/views'
import { workflowModule } from '@wasichai/workflow'
import workerUrl from 'maplibre-gl/dist/maplibre-gl-worker.mjs?worker&url'
import 'maplibre-gl/dist/maplibre-gl.css'
import '@wasichai/documents/print.css'
import './index.css'

// every module the server ships; the assistant is left out, as on the server (wasichai ADR-068)
createRoot(document.getElementById('root')!).render(
    <WasichaiApp
        config={{ apiBaseUrl: '/api', appName: 'Wasichai', appTagline: 'Full sample' }}
        modules={[gisModule({ workerUrl }), workflowModule(), pagesModule(), viewsModule(), formsModule(), documentsModule(), automationModule()]}
    />
)
