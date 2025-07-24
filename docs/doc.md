```mermaid
graph TD
    subgraph Phobos Package
        direction LR

        subgraph User Facing API
            direction TB
            A[User Analysis Code] --> phobos_map("phobos.map()")
            A --> phobos_datasets("phobos.datasets.read_from_hms()")
        end

        subgraph Core Logic & Utilities
            direction TB
            phobos_map -- "is a wrapper for" --> kernel("kernel.kernel()")
            phobos_datasets -- "reads from" --> B((HMS Tables))
            
            subgraph LOB Modules["Line of Business Modules"]
                direction TB
                subgraph appstore
                    direction TB
                    as_clickstream[clickstream]
                    as_movement[movement_event]
                end

                subgraph music
                    direction TB
                    m_clickstream[clickstream]
                    m_paf[paf]
                    m_movement[movement_event]
                end

                subgraph fitness
                    direction TB
                    f_clickstream[clickstream]
                    f_movement[movement_event]
                end
                
                subgraph horizontal
                    h_main[horizontal.py]
                    h_movement[movement_event]
                end
                
                other_lobs[...]
            end

            utils("utils/")
            commentary("commentary/")
        end
    end

    %% Dependencies
    as_clickstream --> kernel
    m_clickstream --> kernel
    f_clickstream --> kernel
    h_main --> kernel
    
    as_clickstream --> utils
    m_clickstream --> utils
    f_clickstream --> utils
    h_main --> utils
    commentary --> utils

    %% Styling
    style Core Logic & Utilities fill:#f9f,stroke:#333,stroke-width:2px
    style User Facing API fill:#ccf,stroke:#333,stroke-width:2px
    style LOB Modules fill:#f8d5a2,stroke:#333,stroke-width:2px
```