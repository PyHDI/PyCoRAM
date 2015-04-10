#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <sys/time.h>

#include "umem.h"
#include "pycoram.h"

//------------------------------------------------------------------------------
#define MAX_NODES (4 * 1024 * 1024)
#define MAX_PAGES (256 * 1024)
#define PAGE_SIZE (8)
#define HASH_SIZE (1024)
#define HASH(__id__) (__id__ % HASH_SIZE)

#define MAX_INT (0xffffffff)

//------------------------------------------------------------------------------
typedef struct node Node;
typedef struct page Page;
typedef struct edge Edge;
typedef struct nodechain Nodechain;
typedef unsigned int Uint;

#include "heap.h"

struct node
{
  Node* parent_node;
  Uint current_cost;
  Page* page_addr;
  Uint visited;
};

struct edge
{
  Node* next_node;
  Uint cost;
};

struct page
{
  Uint num_entries;
  Page* next_page;
  Edge edges [PAGE_SIZE];
};

struct nodechain
{
  Uint id;
  Node* node;
  Nodechain* next;
};

//------------------------------------------------------------------------------
Uint number_of_nodes;
Uint number_of_edges;

Node* node_array;
Page* page_array;
Uint* id_table;  // Address -> ID
Nodechain** addr_table;  // ID -> Address
Nodechain* addr_table_entry;  // ID -> Address

PriorityQueue pqueue;
Heapelement* pqueue_ptr;

Uint node_index; // for node count
Uint page_index; // for edge count
Uint addr_table_entry_index;

//------------------------------------------------------------------------------
Node* get_node(Uint id)
{
  Nodechain* ptr = addr_table[HASH(id)];
  while(ptr != NULL && ptr->id != id){
    ptr = ptr->next;
  }
  if(ptr==NULL) return NULL;
  return ptr->node;
}

//------------------------------------------------------------------------------
void set_node(Uint id, Node* node)
{
  Nodechain* ptr = addr_table[HASH(id)];
  if(ptr == NULL){
    addr_table[HASH(id)] = &addr_table_entry[addr_table_entry_index];
    addr_table_entry_index++;
    addr_table[HASH(id)]->id = id;
    addr_table[HASH(id)]->node = node;
    addr_table[HASH(id)]->next = NULL;
    return;
  }
  while(ptr->next != NULL){
    ptr = ptr->next;
  }
  ptr->next = &addr_table_entry[addr_table_entry_index];
  addr_table_entry_index++;
  ptr->next->id = id;
  ptr->next->node = node;
  ptr->next->next = NULL;
}

//------------------------------------------------------------------------------
Uint get_id(Node* node)
{
  Uint index = (Uint)((((void*) node) - ((void*) node_array))) / sizeof(Node);
  return id_table[index];
}

//------------------------------------------------------------------------------
Node* add_node(Uint id)
{
  Node* ret = get_node(id);
  if(ret == NULL){
    node_array[node_index].parent_node = 0;
    node_array[node_index].current_cost = MAX_INT;
    node_array[node_index].visited = 0;
    node_array[node_index].page_addr = NULL;
    id_table[node_index] = id;
    set_node(id, &node_array[node_index]);
    ret = &node_array[node_index];
    node_index++;
    return ret;
  }
  return ret;
}

//------------------------------------------------------------------------------
void add_edge(Uint from, Uint to, Uint cost)
{
  Node* f = add_node(from);
  Node* t = add_node(to);

  if(f->page_addr == NULL){
    // New page
    f->page_addr = &page_array[page_index];
    page_index++;

    f->page_addr->next_page = NULL;
    f->page_addr->num_entries = 0;
  }

  Page* p = f->page_addr;
  while(p->next_page != NULL){
    p = p->next_page;
  }
  
  if(p->num_entries < PAGE_SIZE){
    p->edges[p->num_entries].next_node = t;
    p->edges[p->num_entries].cost = cost;
    p->num_entries++;
  }else{
    // New page
    p->next_page = &page_array[page_index];
    page_index++;

    p->next_page->next_page = NULL;
    p->next_page->num_entries = 0;

    p = p->next_page;
    p->edges[p->num_entries].next_node = t;
    p->edges[p->num_entries].cost = cost;
    p->num_entries++;
  }
}

//------------------------------------------------------------------------------
void add_frontier(Node* node, Uint cost)
{
  Heapelement he;
  he.value = cost;
  he.data = node;
  enqueue(he, &pqueue);
}

//------------------------------------------------------------------------------
void update_frontiers(Node* current_node)
{
  Uint current_cost = current_node->current_cost;
  Page* page = current_node->page_addr;

  while(page != NULL){
    Uint num_next = page->num_entries;
    Uint i;

    for(i=0; i<num_next; i++){
      //printf("page[%d]\n", i);
      Uint cost = page->edges[i].cost;
      Uint new_cost = current_cost + cost;
      Node* next_node = page->edges[i].next_node;
      if(next_node->current_cost > new_cost){
        //printf("add node:%d cost:%d\n", get_id(next_node), new_cost);
        add_frontier(next_node, new_cost);
        next_node->current_cost = new_cost;
        next_node->parent_node = current_node;
      }
    }
    
    page = page->next_page;
  }
}

//------------------------------------------------------------------------------
int is_frontier_empty()
{
  return is_empty(&pqueue);
}

//------------------------------------------------------------------------------
Node* select_frontier()
{
  //printf("current size=%d\n", pqueue.size);
  Heapelement he = dequeue(&pqueue);
  Node* n = he.data;
  return n;
}

//------------------------------------------------------------------------------
Uint find_shortest_path(Uint start, Uint goal)
{
  Node* current_node = get_node(start);
  Node* goal_node = get_node(goal);
  current_node->current_cost = 0;
  add_frontier(current_node, 0);

  while(current_node != goal_node){
    if(is_frontier_empty()) return MAX_INT;
    current_node = select_frontier();
    if(current_node->visited) continue;
    current_node->visited = 1;
    //printf("current_node=%d current_cost=%d\n", current_node->id, current_node->current_cost);
    update_frontiers(current_node);
  }

  return current_node->current_cost;
}

//------------------------------------------------------------------------------
void walk_result(Uint sum_of_cost, Uint start, Uint goal)
{
  Node* c = get_node(goal);
  printf("route: ");

  while(c != NULL){
    Uint id = get_id(c);
    printf("%d %d\n", id, c->current_cost);
    if(id == start) break;
    c = c->parent_node;
  }
  
  printf("\r\n");
  printf("cost: %d", sum_of_cost);
  printf("\r\n");
}

//------------------------------------------------------------------------------
int main(int argc, char *argv[])
{
  if(argc < 4){
    printf("# Usage: ./a.out start goal filename [runmode]\n");
    return -1;
  }

  FILE* fp = fopen(argv[3], "r");
  if(fp == NULL){
    printf("no such file\n");
    return -1;
  }

  unsigned int start = atoi(argv[1]);
  unsigned int goal = atoi(argv[2]);
  int runmode = 0;
  if(argc > 4){
    runmode = atoi(argv[4]);
  }
  printf("runmode: %d\n", runmode);
  
  if(fscanf(fp, "%d %d\n", &number_of_nodes, &number_of_edges) != 2){
    exit(-1);
  }

  if(number_of_nodes > MAX_NODES || number_of_edges > (MAX_PAGES * PAGE_SIZE)){
    printf("Graph size exceeds the maximum memory capacity.");
    return -1;
  }

  node_index = 0;
  page_index = 0;
  addr_table_entry_index = 0;

  if(runmode == 0){
    node_array = (Node*) malloc(sizeof(Node) * number_of_nodes);
    if(node_array == NULL){
      printf("can not allocate a memory for node_array.\n");
      exit(-1);
    }
    page_array = (Page*) malloc(sizeof(Page) * number_of_edges);
    if(page_array == NULL){
      printf("can not allocate a memory for page_array.\n");
      exit(-1);
    }
    id_table = (Uint*) malloc(sizeof(Uint) * number_of_nodes);
    if(id_table == NULL){
      printf("can not allocate a memory for id_table.\n");
      exit(-1);
    }
    addr_table = (Nodechain**) malloc(sizeof(Nodechain*) * HASH_SIZE);
    if(addr_table == NULL){
      printf("can not allocate a memory for addr_table.\n");
      exit(-1);
    }
    addr_table_entry = (Nodechain*) malloc(sizeof(Nodechain) * number_of_nodes);
    if(addr_table_entry == NULL){
      printf("can not allocate a memory for addr_table_entry.\n");
      exit(-1);
    }
    pqueue_ptr = (Heapelement*) malloc(sizeof(Heapelement) * (number_of_nodes+1));
    if(pqueue_ptr == NULL){
      printf("can not allocate a memory for pqueue_ptr.\n");
      exit(-1);
    }
  }
  else{
    umem_open();
    printf("# UMEM is opened.\n");
    
    node_array = (Node*) umem_malloc(sizeof(Node) * number_of_nodes);
    if(node_array == NULL){
      printf("can not allocate a memory for node_array.\n");
      exit(-1);
    }
    page_array = (Page*) umem_malloc(sizeof(Page) * number_of_edges);
    if(page_array == NULL){
      printf("can not allocate a memory for page_array.\n");
      exit(-1);
    }
    id_table = (Uint*) umem_malloc(sizeof(Uint) * number_of_nodes);
    if(id_table == NULL){
      printf("can not allocate a memory for id_table.\n");
      exit(-1);
    }
    addr_table = (Nodechain**) umem_malloc(sizeof(Nodechain*) * HASH_SIZE);
    if(addr_table == NULL){
      printf("can not allocate a memory for addr_table.\n");
      exit(-1);
    }
    addr_table_entry = (Nodechain*) umem_malloc(sizeof(Nodechain) * number_of_nodes);
    if(addr_table_entry == NULL){
      printf("can not allocate a memory for addr_table_entry.\n");
      exit(-1);
    }
    pqueue_ptr = (Heapelement*) umem_malloc(sizeof(Heapelement) * (number_of_nodes+1));
    if(pqueue_ptr == NULL){
      printf("can not allocate a memory for pqueue_ptr.\n");
    exit(-1);
    }
  }
  
  init_queue(&pqueue, pqueue_ptr);

  Uint i;
  for(i=0; i<number_of_nodes; i++){
    id_table[i] = 0;
  }
  for(i=0; i<HASH_SIZE; i++){
    addr_table[i] = NULL;
  }

  Uint from, to, cost;

  while(fscanf(fp, "%d %d %d\n", &from, &to, &cost) == 3){
    add_edge(from, to, cost);
    //add_edge(to, from, cost); // undirected graph
  }

  /*
  while(fscanf(stdin, "%d %d %d\n", &from, &to, &cost) == 3){
    add_edge(from, to, cost);
    //add_edge(to, from, cost); // undirected graph
  }
  */

  printf("start:%d goal:%d\r\n", start, goal);
  printf("num_nodes:%d num_edges:%d\r\n", number_of_nodes, number_of_edges);

  struct timeval s, e;

  Uint sum_of_cost;
  Uint cycles;

  if(runmode == 0 || runmode == 1){
    gettimeofday(&s, NULL);
    sum_of_cost = find_shortest_path(start, goal);
    gettimeofday(&e, NULL);
    cycles = 0;
  }else{
    printf("# with PyCoRAM\n");
    Node* start_addr = get_node(start);
    Node* goal_addr = get_node(goal);
    umem_cache_clean((char*)node_array, sizeof(Node) * number_of_nodes);
    umem_cache_clean((char*)page_array, sizeof(Node) * number_of_edges);

    pycoram_open();

    unsigned int pqueue_ptr_offset = umem_get_physical_address((void*)pqueue_ptr);
    unsigned int start_addr_offset = umem_get_physical_address((void*)start_addr);
    unsigned int goal_addr_offset = umem_get_physical_address((void*)goal_addr);

    pycoram_write_4b(pqueue_ptr_offset);
    pycoram_write_4b(start_addr_offset);
    pycoram_write_4b(goal_addr_offset);

    gettimeofday(&s, NULL);
    pycoram_read_4b(&sum_of_cost);
    pycoram_read_4b(&cycles);
    gettimeofday(&e, NULL);

    pycoram_close();
    //sleep(1);
  }

  double exec_time = (e.tv_sec - s.tv_sec) + (e.tv_usec - s.tv_usec) * 1.0E-6;

  if(sum_of_cost < MAX_INT){
    walk_result(sum_of_cost, start, goal);
  }

  printf("exectuion time=%lf\n", exec_time);

  if(runmode == 0){
    free(node_array);
    free(page_array);
    free(id_table);
    free(addr_table);
    free(addr_table_entry);
  }else{
    umem_close();
  }

  return 0;
}
